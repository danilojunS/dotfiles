#!/bin/zsh

# Point Claude Code's status line at statusline.sh here. settings.json holds
# per-machine things too (hooks, autoMode), so it stays a local file and only
# its "statusLine" key is set, leaving the rest as it is.
#
# Claude Code reruns the status line after each reply and when the model, mode
# or PR changes, but not while the session sits idle; refreshInterval (seconds)
# reruns it anyway, so a branch switched or a commit made from another terminal
# shows up, and a /loop that ended stops showing.
settings=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$settings" ] || echo '{}' > "$settings"

tmp=$settings.tmp
jq '.statusLine = {type: "command", command: "zsh ~/.dotfiles/shell/_tools/claude/statusline.sh", refreshInterval: 30}' \
  "$settings" > "$tmp" && mv "$tmp" "$settings" || { rm -f "$tmp"; exit 1; }
