# dotfiles
My dotfiles :)

## A new Mac

1. Clone and link. `scripts/setup.sh` installs oh-my-zsh and Homebrew, and links
   every `*.symlink` file into `~` as a dotfile (`shell/zsh/zshrc.symlink` is
   `~/.zshrc`):

   ```sh
   git clone git@github.com:danilojunS/dotfiles.git ~/.dotfiles
   ~/.dotfiles/scripts/setup.sh
   brew install herdr jq
   brew install --cask ghostty
   ```

2. The font: install `fonts/Meslo/*.ttf` (open them, or copy them to
   `~/Library/Fonts`). The prompt's icons need it.

3. The machine's colour: one word in `~/.ssh/host-theme`, a flavour from
   `_ssh_theme_flavour` in `shell/ssh-theme.sh` (`foxpuccin`, `mocha`, ...).
   Each machine has its own, so a window always says where it is:
   - a local shell paints its window in this machine's colour;
   - `ssh` into a machine that declares one, and the window takes that
     machine's colour (it announces it from its login shell, nothing needed on
     this side), then comes back to this one's on exit;
   - a machine with no colour of its own, or one to show differently from here,
     gets an entry in `~/.ssh/themes` (see `shell/ssh-themes.example`); that
     entry wins over what the machine announces.

4. Ghostty: `terminal/ghostty/install.sh` links its config. Then, on the Mac
   itself, not over SSH:
   - Ctrl+Tab shows and hides it once Ghostty has Accessibility (System
     Settings > Privacy & Security > Accessibility). For it to come up on the
     desktop you are on, not take you to its own: right-click its Dock icon,
     Options > Assign To > All Desktops.
   - Downloads, Desktop and Documents need Ghostty under Files and Folders on
     the same screen; everything run from it, herdr's panes included, gets
     what Ghostty has.
   - The window in the machine's colour too: its background and foreground in
     `~/.config/ghostty/config.local`, e.g. for foxpuccin:

     ```
     background = #1c1612
     foreground = #f3e5da
     ```

5. herdr: `shell/_tools/herdr/install.sh` writes `~/.config/herdr/config.toml`
   from the shared config, the theme named in `~/.ssh/host-theme`, and
   `~/.config/herdr/config.local.toml` if there is one.

6. Claude Code's status line: `shell/_tools/claude/install.sh`.
