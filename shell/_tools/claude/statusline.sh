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

# Loop and crons: a /loop's next wakeup (⟳ HH:MM) and how many cron jobs the
# session has (⏰ N). Claude Code keeps both in memory and sends neither here,
# so they are worked out from the transcript: CronCreate, CronDelete and
# ScheduleWakeup results since this process started (a resumed session lost
# the old ones). One-shot jobs end at their fire time, recurring ones expire
# after 7 days; a wakeup counts for 5 minutes past its time, while the turn it
# woke runs and schedules the next.
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
tools='"name":"(CronCreate|CronDelete|ScheduleWakeup)"'
if [ -f "$transcript" ] && grep -qE "$tools" "$transcript"; then
  reg=$(grep -lF "\"sessionId\":\"$session\"" ~/.claude/sessions/*.json 2>/dev/null | head -1)
  started=$([ -n "$reg" ] && jq -r '.startedAt // 0' "$reg" || echo 0)
  uses=$(grep -E "$tools" "$transcript")
  ids=$(jq -r '.message.content[]? | select(.type == "tool_use") | .id' <<<"$uses")
  read -r loop crons < <(
    { print -r -- "$uses"; grep -F "$ids" "$transcript" | grep -F '"toolUseResult"'; } |
      jq -rs --argjson started "$started" --argjson now "$(date +%s)000" '
        (map(.message.content[]? | select(.type == "tool_use") | {(.id): .name}) | add) as $names
        | map(select(.type == "user" and .toolUseResult and .timestamp)
              | {t: (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 * 1000),
                 name: $names[.message.content[0].tool_use_id // ""], r: .toolUseResult}
              | select(.name and .t >= $started))
        | sort_by(.t)
        | reduce .[] as $e ({jobs: {}, wake: null};
            if $e.name == "CronCreate" then
              .jobs[$e.r.id] = (if $e.r.recurring then $e.t + 7 * 86400000 else $e.r.nextFireAt end)
            elif $e.name == "CronDelete" then del(.jobs[$e.r.id])
            elif $e.r.stopped then .wake = null
            else .wake = $e.r.scheduledFor end)
        | [(if .wake and .wake + 300000 > $now then .wake / 1000 | floor else 0 end),
           ([.jobs[] | select(. > $now)] | length)] | @tsv')
  (( loop )) && out+="  %F{cyan}⟳ $(date -r "$loop" +%H:%M 2>/dev/null || date -d "@$loop" +%H:%M)%f"
  (( crons )) && out+="  %F{cyan}⏰ $crons%f"
fi

print -P -- "$out"
