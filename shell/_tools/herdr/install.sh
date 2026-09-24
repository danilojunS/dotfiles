#!/bin/zsh

# Link the shared herdr config into place, keeping any existing file aside.
mkdir -p ~/.config/herdr
conf=~/.config/herdr/config.toml
[ -f "$conf" ] && [ ! -L "$conf" ] && mv "$conf" "$conf.bak"
ln -sfn ~/.dotfiles/shell/_tools/herdr/config.toml "$conf"
