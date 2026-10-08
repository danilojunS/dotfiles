#!/bin/zsh
# Claude Code status line: folder, git branch, and the worktree name when the
# session is in a linked worktree rather than the main checkout.
# Claude Code pipes the session as JSON on stdin; install.sh points
# ~/.claude/settings.json here.

dir=$(jq -r '.workspace.current_dir // .cwd // empty')
[ -n "$dir" ] || dir=$PWD

out="%F{blue}${dir/#$HOME/~}%f"

if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD || git -C "$dir" rev-parse --short HEAD)
  out+="  %F{magenta} $branch%f"

  # A linked worktree has its own git dir under the main repo's .git/worktrees.
  gitdir=$(git -C "$dir" rev-parse --absolute-git-dir)
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir)
  if [ "$gitdir" != "$common" ]; then
    top=$(git -C "$dir" rev-parse --show-toplevel)
    out+="  %F{yellow}worktree ${top:t}%f"
  fi

  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -1)" ] && out+=" %F{red}*%f"
fi

print -P -- "$out"
