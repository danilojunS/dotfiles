#!/bin/zsh
# ccupdate: update Claude Code, then restart every idle Claude Code session in
# herdr onto the new version, so none of them needs "restart to update". Each
# one is /exit-ed in its pane and resumed there with `claude --resume <id>`, in
# the folder it was in at the time (its worktree, if it had moved into one).
#
#   ccupdate [-n]     -n: skip the update, only say what would be restarted
#
# A session is left alone when it is already on the installed version, when
# herdr or Claude Code says it is not idle, when its prompt holds a draft (the
# /exit would be sent along with it), or when it is the pane this runs in. A
# session in a worktree keeps it: ccupdate answers "Keep worktree" on the way out.
#
# The session id comes from Claude Code's own ~/.claude/sessions/<pid>.json,
# not from herdr: herdr's agent_session can lag behind a pane that resumed or
# switched sessions, and resuming that id brings back the wrong conversation.

dry=0
[ "$1" = -n ] && dry=1

herdr=${HERDR_BIN_PATH:-$(whence -p herdr)}

(( dry )) || claude update || exit 1

[ -n "$HERDR_SOCKET_PATH" ] || { echo "ccupdate: not inside herdr, no sessions to restart" >&2; exit 0; }

latest=$(readlink -f "$(whence -p claude)")
latest=${latest:t}
echo "installed Claude Code: $latest"

# The prompt is empty when the line after the last "❯" is the box's bottom rule.
prompt_is_empty() {
  "$herdr" pane read --source visible "$1" 2>/dev/null |
    awk '/^❯/ { prompt = $0; getline next_line; last = prompt "\n" next_line }
         END { split(last, l, "\n"); exit !(l[1] ~ /^❯[[:space:]]*$/ && l[2] ~ /^─/) }'
}

# /exit in a worktree session opens "Exiting worktree session" with the cursor
# on "1. Keep worktree"; only then is Enter safe to send.
keep_worktree_asked() {
  "$herdr" pane read --source visible "$1" 2>/dev/null | grep -q '❯ 1\. Keep worktree'
}

claude_pid() {
  "$herdr" pane process-info --pane "$1" |
    jq -r '.result.process_info.foreground_processes[] | select(.argv0 == "claude") | .pid' | head -1
}

wait_until() {
  local i
  for i in {1..30}; do
    eval "$1" && return 0
    sleep 0.5
  done
  return 1
}

# An array rather than a pipe into the loop, so nothing in it reads the list.
panes=("${(@f)$("$herdr" pane list | jq -r '.result.panes[] | select(.agent == "claude") | "\(.pane_id) \(.agent_status)"')}")
for line in "${panes[@]}"; do
  pane=${line%% *} state=${line#* }
  [ "$pane" = "$HERDR_PANE_ID" ] && { echo "$pane: skipped, this pane"; continue; }

  pid=$(claude_pid "$pane")
  reg=~/.claude/sessions/$pid.json
  [ -n "$pid" ] && [ -f "$reg" ] || { echo "$pane: skipped, no Claude Code session found"; continue; }

  id=$(jq -r .sessionId "$reg")
  # Where the session is now, not where it started: sessions.json keeps the
  # launch folder, but a session that went into a worktree (or cd-ed) has
  # moved on, and resuming in the launch folder would put it back on the main
  # checkout. The transcript's last entry has the current folder, but only once
  # this process has written one; before that (just resumed, nothing sent yet)
  # the process's own folder is the one it was resumed in.
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  [ -d "$cwd" ] || cwd=$(jq -r .cwd "$reg")
  transcript=(~/.claude/projects/*/$id.jsonl(N[1]))
  if (( ${#transcript} )); then
    started=$(jq -r '.startedAt / 1000 | floor' "$reg")
    now=$(tail -n 200 "$transcript" | jq -r --argjson started "$started" '
      select(.cwd and .timestamp)
      | select((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $started)
      | .cwd' 2>/dev/null | tail -1)
    [ -n "$now" ] && [ -d "$now" ] && cwd=$now
  fi
  version=$(jq -r .version "$reg")
  name=$(jq -r '.name // .sessionId' "$reg")
  label="$pane ($name)"

  [ "$version" = "$latest" ] && { echo "$label: already on $version"; continue; }
  [ "$state" = idle ] && [ "$(jq -r .status "$reg")" = idle ] ||
    { echo "$label: skipped, working"; continue; }
  prompt_is_empty "$pane" || { echo "$label: skipped, prompt has a draft"; continue; }

  # Keep the flags it was started with, minus the resume/continue ones.
  args=()
  argv=("${(@f)$("$herdr" pane process-info --pane "$pane" |
    jq -r --argjson pid "$pid" '.result.process_info.foreground_processes[] | select(.pid == $pid) | (.argv // [])[1:][]')}")
  for (( i = 1; i <= ${#argv}; i++ )); do
    case ${argv[i]} in
      -c|--continue|'') ;;
      -r|--resume) [[ ${argv[i+1]} == -* ]] || (( i++ )) ;;
      --resume=*) ;;
      *) args+=("${argv[i]}") ;;
    esac
  done

  if (( dry )); then
    echo "$label: would restart $version -> $latest in ${cwd/#$HOME/~}"
    continue
  fi

  "$herdr" pane run "$pane" "/exit" >/dev/null
  # A session in a worktree asks whether to keep it on the way out; keep it.
  if wait_until "! kill -0 $pid 2>/dev/null || keep_worktree_asked $pane"; then
    keep_worktree_asked "$pane" && "$herdr" pane send-keys "$pane" enter >/dev/null
  fi
  wait_until "! kill -0 $pid 2>/dev/null" || { echo "$label: did not exit, left as it was"; continue; }

  # A subshell, so the pane's shell stays in its own folder.
  "$herdr" pane run "$pane" "(cd ${(q)cwd} && claude ${(j: :)${(q)args}} --resume $id)" >/dev/null
  if wait_until '[ "$(jq -r .sessionId ~/.claude/sessions/$(claude_pid $pane).json 2>/dev/null)" = "$id" ]'; then
    echo "$label: restarted $version -> $latest"
  else
    echo "$label: exited but did not come back; resume it with: claude --resume $id" >&2
  fi
done
