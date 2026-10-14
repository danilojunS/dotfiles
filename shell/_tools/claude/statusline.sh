#!/bin/zsh
# Claude Code status line: how full the context window is, the git branch, and
# the worktree name when the session is in a linked worktree, or "main" when it
# is on the main checkout. The
# folder is left out for now: it is where the session was started, already
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

print -P -- "$out"
