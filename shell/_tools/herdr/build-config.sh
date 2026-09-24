#!/bin/zsh

# Write ~/.config/herdr/config.toml: the shared config.toml here with this
# machine's ~/.config/herdr/config.local.toml (optional) merged on top.
#
# It is a generated file rather than a symlink because the brew-managed server
# reads it too, and the server draws the panes: their borders take the theme's
# accent from the server's config, not the attaching client's. A symlink to the
# shared file would leave the server on the shared theme whatever the local
# file says.
#
# When the result differs from what is there, the file is replaced and a
# running server is told to reload it. Called by install.sh and by the herdr()
# wrapper in shell/dj.sh, so an edit to either source lands on the next
# `herdr`. Exits non-zero, leaving config.toml alone, if the merge fails.

here=${0:A:h}
dir=~/.config/herdr
conf=$dir/config.toml
tmp=$conf.tmp

sources=("$here/config.toml")
[ -f "$dir/config.local.toml" ] && sources+=("$dir/config.local.toml")

python3 "$here/merge-config.py" "$tmp" "${sources[@]}" || { rm -f "$tmp"; exit 1; }

if cmp -s "$tmp" "$conf"; then
  rm -f "$tmp"
  exit 0
fi

# mv, not a write through $conf, so an old symlink is replaced rather than the
# shared file it points at.
mv -f "$tmp" "$conf"
command herdr server reload-config >/dev/null 2>&1
exit 0
