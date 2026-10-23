#!/bin/zsh
# Claude Code status line: how full the context window is, the git branch, the
# worktree name when the session is in a linked worktree (or "main" when it is
# on the main checkout), and any /loop or cron jobs the session has running.
# The folder is left out for now: it is where the session was started, already
# known.
# Claude Code pipes the session as JSON on stdin; install.sh points
# ~/.claude/settings.json here.

input=$(cat)
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
[ -n "$dir" ] || dir=$PWD

out=""

# Context window: a 10-cell bar and the percentage used, green up to 50%, then
# yellow, red from 80% (auto-compact is near). Absent before the first reply.
pct=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
if [ -n "$pct" ]; then
  pct=${pct%.*}
  filled=$(( (pct + 5) / 10 )); (( filled > 10 )) && filled=10
  if (( pct >= 80 )); then color=red elif (( pct >= 50 )); then color=yellow else color=green fi
  out+="%F{$color}${(pl:$filled::█:)}%F{8}${(pl:$((10 - filled))::░:)}%f %F{$color}$pct%%%f  "
fi

if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD || git -C "$dir" rev-parse --short HEAD)
  out+="%F{magenta} $branch%f"

  # A linked worktree has its own git dir under the main repo's .git/worktrees.
  gitdir=$(git -C "$dir" rev-parse --absolute-git-dir)
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir)
  if [ "$gitdir" != "$common" ]; then
    top=$(git -C "$dir" rev-parse --show-toplevel)
    out+="  %F{yellow}${top:t}%f"
  else
    out+="  %F{yellow}main%f"
  fi

  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -1)" ] && out+=" %F{red}*%f"
fi

# Loop and crons: when a /loop wakes next ( HH:MM), and when the next cron
# job runs ( HH:MM, with how many there are when more than one). Claude Code
# keeps both in memory and sends neither here; statusline-jobs.py works them
# out from the transcript: the crons since they were created (a resume brings
# them back), the loop only since this process started (a resume does not).
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
if [ -f "$transcript" ] && grep -qE '"name":"(CronCreate|ScheduleWakeup)"' "$transcript"; then
  reg=$(grep -lF "\"sessionId\":\"$session\"" ~/.claude/sessions/*.json 2>/dev/null | head -1)
  started=$([ -n "$reg" ] && jq -r '.startedAt // 0' "$reg" || echo 0)
  read -r loop cron jobs < <(python3 -I "${0:A:h}/statusline-jobs.py" "$transcript" "$started" 2>/dev/null)
  # A time today as HH:MM, a later one with its day too.
  zmodload zsh/datetime
  when() {
    local fmt=%H:%M
    [ "$(strftime %F "$1")" = "$(strftime %F $EPOCHSECONDS)" ] || fmt="%d/%m %H:%M"
    strftime "$fmt" "$1"
  }
  (( loop )) && loop_txt=" $(when $loop)"
  if (( cron )); then
    cron_txt=" $(when $cron)"
    (( jobs > 1 )) && cron_txt+=" ($jobs)"
  fi
  [ -n "$loop_txt" ] && out+="  %F{cyan}$loop_txt%f"
  [ -n "$cron_txt" ] && out+="  %F{cyan}$cron_txt%f"
fi

# herdr's sidebar: the loop and crons above, and how many shells the session
# has running (a Bash call in the background, mostly), as $loop, $cron and $bg
# tokens on this pane for the claude rows in shell/_tools/herdr/config.toml.
# Those shells are Claude Code's children sourcing its shell snapshot. An empty
# value clears a token; the TTL clears them all when the session goes away
# without another refresh (install.sh sets refreshInterval to 30s). Sent in the
# background so the status line does not wait on herdr.
if [ -n "$HERDR_PANE_ID" ]; then
  shells=$(pgrep -P $PPID -f shell-snapshots | wc -l)
  (( shells )) && bg_txt=" $(( shells ))"
  "${HERDR_BIN_PATH:-herdr}" pane report-metadata "$HERDR_PANE_ID" --source claude-statusline \
    --token "loop=$loop_txt" --token "cron=$cron_txt" --token "bg=$bg_txt" \
    --ttl-ms 90000 >/dev/null 2>&1 &!
fi

print -P -- "$out"
