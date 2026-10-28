#!/bin/zsh

# Point Ghostty at config.ghostty here. Ghostty reads ~/.config/ghostty first;
# the template it writes to Application Support on first run sets nothing, so
# it is left as it is.
mkdir -p ~/.config/ghostty
ln -sfn ~/.dotfiles/terminal/ghostty/config.ghostty ~/.config/ghostty/config.ghostty
