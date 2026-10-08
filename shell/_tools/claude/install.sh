#!/bin/zsh

# Point Claude Code's status line at statusline.sh here. settings.json holds
# per-machine things too (hooks, autoMode), so it stays a local file and only
# its "statusLine" key is set, leaving the rest as it is.
settings=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$settings" ] || echo '{}' > "$settings"

tmp=$settings.tmp
jq '.statusLine = {type: "command", command: "zsh ~/.dotfiles/shell/_tools/claude/statusline.sh"}' \
  "$settings" > "$tmp" && mv "$tmp" "$settings" || { rm -f "$tmp"; exit 1; }
