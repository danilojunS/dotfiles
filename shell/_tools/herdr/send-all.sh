#!/bin/sh

# prefix+a in config.toml: ask for a command and run it in every pane of the
# active tab, like tmux's synchronize-panes in ~/.tmux.conf. herdr has no live
# input sync, so this is one line typed once, not every keystroke mirrored.
# Agent panes get it too, as a prompt.

printf 'send to all panes: '
IFS= read -r cmd || exit 0
[ -n "$cmd" ] || exit 0

"$HERDR_BIN_PATH" pane list --workspace "$HERDR_ACTIVE_WORKSPACE_ID" |
  python3 -c '
import json, sys
for p in json.load(sys.stdin)["result"]["panes"]:
    if p["tab_id"] == sys.argv[1]:
        print(p["pane_id"])
' "$HERDR_ACTIVE_TAB_ID" |
  while read -r pane; do
    "$HERDR_BIN_PATH" pane run "$pane" "$cmd" >/dev/null
  done
