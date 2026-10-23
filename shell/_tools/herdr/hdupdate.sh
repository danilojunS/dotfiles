#!/bin/zsh
# hdupdate: bring every herdr pane up to date, each by what it runs:
#
#   - a shell with nothing running in it reloads (exec zsh), so it picks up
#     this dotfiles' current functions, aliases and PATH;
#   - Claude Code is updated and restarted on the new version, as ccupdate
#     does (shell/_tools/claude/ccupdate.sh, sourced here), its background
#     sessions (claude --bg) included;
#   - Codex is updated and restarted the same way: /quit, then
#     `codex resume <id>` in the folder the session works in;
#   - anything else (an editor, ssh, a server, a build) is left alone.
#
#   hdupdate [-n] [-a]
#     -n  skip the updates, only say what would be done
#     -a  restart Claude Code and Codex sessions already on the installed
#         version too, e.g. so they pick up changed hooks or settings
#
# The rules ccupdate keeps for Claude Code hold for Codex too: a session is
# restarted only when idle, with an empty prompt (the /quit would go out with a
# draft), and never in the pane this runs in. A shell reloads only at an empty
# prompt. All panes go at once.

source ~/.dotfiles/shell/_tools/claude/ccupdate.sh

dry=0 all=0
for arg; do
  case $arg in
    -n) dry=1 ;;
    -a) all=1 ;;
    *) echo "usage: hdupdate [-n] [-a]" >&2; exit 2 ;;
  esac
done

[ -n "$HERDR_SOCKET_PATH" ] || { echo "hdupdate: not inside herdr" >&2; exit 1; }
herdr=${HERDR_BIN_PATH:-$(whence -p herdr)}

if (( ! dry )); then
  claude update || echo "hdupdate: Claude Code did not update, restarting onto the version installed" >&2
  if whence -p codex >/dev/null; then
    codex update || echo "hdupdate: Codex did not update, restarting onto the version installed" >&2
  fi
fi

claude_latest=$(readlink -f "$(whence -p claude)")
claude_latest=${claude_latest:t}
echo "installed Claude Code: $claude_latest"

# The standalone install keeps each Codex release in a folder named after it,
# .../releases/<version>-<target>/bin/codex; a running session's binary says
# which one it is on.
codex_version() {
  local exe=$1
  exe=${exe:h:h:t}
  print -r -- ${exe%%-*}
}
if whence -p codex >/dev/null; then
  codex_latest=$(codex_version "$(readlink -f "$(whence -p codex)")")
  echo "installed Codex: $codex_latest"
fi

pane_processes() {
  "$herdr" pane process-info --pane "$1" | jq -c '.result.process_info'
}

# --- Shells --------------------------------------------------------------------

# The prompt (powerlevel10k's, two lines) is empty when its last "❯" line has
# nothing typed after it, the right prompt's closing "─╯" aside.
shell_prompt_is_empty() {
  "$herdr" pane read --source visible "$1" 2>/dev/null |
    awk '/^❯/ { last = $0 }
         END { if (last == "") exit 1
               sub(/^❯/, "", last); gsub(/[─╯[:space:]]/, "", last)
               exit last != "" }'
}

shell_reload_pane() {
  local pane=$1 info argv0 cmd
  info=$(pane_processes "$pane")
  # The shell alone in the foreground: nothing started from it is running.
  [ "$(jq '(.foreground_processes | length) == 1 and .foreground_processes[0].pid == .shell_pid' <<<"$info")" = true ] ||
    { echo "$pane: skipped, $(jq -r '[.foreground_processes[] | select(.pid != .shell_pid) | .argv0] | unique | join(", ")' <<<"$info") running"; return; }
  # Nor in the background: exec would take its jobs (cmd &) down with it.
  pgrep -qP "$(jq -r .shell_pid <<<"$info")" &&
    { echo "$pane: skipped, the shell has jobs running in the background"; return; }
  argv0=$(jq -r '.foreground_processes[0].argv0' <<<"$info")
  [ "$argv0" = zsh ] || { echo "$pane: skipped, a $argv0 shell"; return; }
  shell_prompt_is_empty "$pane" || { echo "$pane: skipped, prompt has a draft"; return; }

  # A login shell ("-zsh") stays one.
  cmd="exec zsh"
  [[ $(jq -r '.foreground_processes[0].argv[0]' <<<"$info") == -* ]] && cmd="exec zsh -l"
  if (( dry )); then
    echo "$pane: would reload the shell"
  else
    "$herdr" pane run "$pane" "$cmd" >/dev/null && echo "$pane: shell reloaded"
  fi
}

# --- Codex ---------------------------------------------------------------------

codex_pid() {
  "$herdr" pane process-info --pane "$1" |
    jq -r '.result.process_info.foreground_processes[] | select(.argv0 == "codex") | .pid' | head -1
}

# A running session holds ~/.codex/thread-writer-locks/<thread id>.lock for each
# thread it writes, its subagents' too; the session is the one no other thread
# spawned. It takes the lock on its first write only, though: a session just
# resumed has none yet. Then herdr's record of it (from the herdr hook, when
# its hooks are trusted) or the id it was resumed with will do.
codex_thread() {
  local pid=$1 t
  local -a threads
  threads=(${${(f)"$(lsof -p "$pid" -Fn 2>/dev/null | sed -n 's|^n.*/thread-writer-locks/\([0-9a-f-]*\)\.lock$|\1|p')"}})
  for t in $threads; do
    [ -n "$(sqlite3 ~/.codex/state_5.sqlite "select 1 from thread_spawn_edges where child_thread_id = '$t'" 2>/dev/null)" ] ||
      { print -r -- $t; return; }
  done
}

codex_session() {
  local pane=$1 pid=$2 id
  id=$(codex_thread "$pid")
  [ -n "$id" ] || id=$("$herdr" pane get "$pane" |
    jq -r '.result.pane.agent_session | select(.agent == "codex") | .value // empty' 2>/dev/null)
  [ -n "$id" ] || id=$(ps -o args= -p "$pid" | awk '{ for (i = 1; i < NF; i++) if ($i == "resume") { print $(i + 1); exit } }')
  [[ $id =~ '^[0-9a-f]{8}-[0-9a-f-]{27}$' ]] && print -r -- $id
}

# Codex shows a dimmed placeholder ("Ask Codex to do anything") in an empty
# prompt, typed text is not dimmed; its animated background of braille dots
# runs through the line too. So: the first character after "›" that is neither
# a space nor one of those dots is either dimmed (empty) or not (a draft).
codex_prompt_is_empty() {
  "$herdr" pane read --source visible --ansi "$1" 2>/dev/null | grep -a '›' | tail -1 |
    perl -CS -e '
      $_ = <STDIN>; exit 1 unless defined && s/^.*?\x{203A}//;
      my $dim = 0;
      while (/\G(?:\e\[([0-9;]*)m|([\s\x{2800}-\x{28FF}])|(.))/gc) {
        if (defined $1) {
          my @p = split /;/, ($1 eq "" ? "0" : $1);
          while (@p) {
            my $x = shift @p;
            if ($x == 38 || $x == 48) { my $m = shift @p; splice @p, 0, ($m == 5 ? 1 : 3) }
            elsif ($x == 0 || $x == 22) { $dim = 0 }
            elsif ($x == 2) { $dim = 1 }
          }
        } elsif (defined $3) { exit($dim ? 0 : 1) }
      }
      exit 0'
}

codex_restart_pane() {
  local line=$1 pane state pid id cwd version label i
  local -a args argv
  pane=${line%% *} state=${line#* }
  [ "$pane" = "$HERDR_PANE_ID" ] && { echo "$pane: skipped, this pane"; return; }

  pid=$(codex_pid "$pane")
  [ -n "$pid" ] || { echo "$pane: skipped, no Codex process found"; return; }
  version=$(codex_version "$(lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)")
  id=$(codex_session "$pane" "$pid")
  label="$pane (codex${id:+ ${id[1,8]}})"

  (( all )) || [ "$version" != "$codex_latest" ] || { echo "$label: already on $version"; return; }
  [ "$state" = idle ] || { echo "$label: skipped, working"; return; }
  codex_prompt_is_empty "$pane" || { echo "$label: skipped, prompt has a draft"; return; }

  # The folder the session works in, as Codex recorded it; else the process's.
  [ -n "$id" ] && cwd=$(sqlite3 ~/.codex/state_5.sqlite "select cwd from threads where id = '$id'" 2>/dev/null)
  [ -d "$cwd" ] || cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')

  # Keep the options it was started with; a prompt or a resume/fork is dropped.
  args=()
  argv=("${(@f)$("$herdr" pane process-info --pane "$pane" |
    jq -r --argjson pid "$pid" '.result.process_info.foreground_processes[] | select(.pid == $pid) | (.argv // [])[1:][]')}")
  for (( i = 1; i <= ${#argv}; i++ )); do
    case ${argv[i]} in
      resume|fork|--last) [ "${argv[i]}" = --last ] || (( i++ )) ;;
      -m|--model|-c|--config|-p|--profile|-s|--sandbox|-a|--ask-for-approval|-C|--cd|--enable|--disable|-i|--image|--add-dir|--local-provider)
        args+=("${argv[i]}" "${argv[i+1]}"); (( i++ )) ;;
      -*) args+=("${argv[i]}") ;;
      *) ;;
    esac
  done

  if (( dry )); then
    echo "$label: would restart $version -> $codex_latest in ${cwd/#$HOME/~}"
    return
  fi

  "$herdr" pane run "$pane" "/quit" >/dev/null
  wait_until "! kill -0 $pid 2>/dev/null" || { echo "$label: did not exit, left as it was"; return; }

  # A session with nothing sent yet has nothing to resume: it starts afresh.
  "$herdr" pane run "$pane" "(cd ${(q)cwd} && codex ${id:+resume }${(j: :)${(@q)args}} $id)" >/dev/null
  # Back once a Codex on the installed version runs in the pane.
  if wait_until '[ "$(codex_version "$(lsof -a -p "$(codex_pid $pane)" -d txt -Fn 2>/dev/null | sed -n "s/^n//p" | head -1)")" = "$codex_latest" ]'; then
    # Codex asks again at every start while ~/.codex/hooks.json has hooks
    # nobody trusted yet; that answer is the user's.
    sleep 2
    if "$herdr" pane read --source visible "$pane" 2>/dev/null | grep -q 'Hooks need review'; then
      echo "$label: restarted $version -> $codex_latest, waiting on its hooks review"
    else
      echo "$label: restarted $version -> $codex_latest"
    fi
  else
    echo "$label: exited but did not come back${id:+; resume it with: codex resume $id}" >&2
  fi
}

# --- All panes -----------------------------------------------------------------

panes=("${(@f)$("$herdr" pane list | jq -r '.result.panes[] | "\(.pane_id) \(.agent // "-") \(.agent_status)"')}")
for line in "${panes[@]}"; do
  [ -n "$line" ] || continue
  pane=${line%% *} rest=${line#* }
  agent=${rest%% *} state=${rest#* }
  case $agent in
    claude) claude_restart_pane "$pane $state" & ;;
    codex) codex_restart_pane "$pane $state" & ;;
    -) [ "$pane" = "$HERDR_PANE_ID" ] || shell_reload_pane "$pane" & ;;
    *) echo "$pane: skipped, $agent running" ;;
  esac
done

claude_respawn_all_bg
wait
