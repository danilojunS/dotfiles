## Put here are all common alias and scripts for bash and zsh shells

## Detect OS

OS='unknown'
if [[ $(uname) == 'Darwin' ]]; then
  OS='osx'
elif [[ $(uname) == 'Linux' ]]; then
  OS='linux'
fi

## ssh-agent is set up in zsh/zshrc.symlink, above the p10k instant prompt
## block. On Linux/WSL that block starts an agent but deliberately loads no
## keys, so startup can never block on a passphrase; load the key by hand once
## per boot with this. (On macOS the agent already holds it and this no-ops.)
sshkey() {
  ssh-add -l >/dev/null 2>&1 && return 0   # agent already holds a key
  ssh-add "${1:-$HOME/.ssh/id_ed25519}"
}

## Cross-SSH clipboard + file transfer (rtcopy, rtpaste, rtsend)
[ -f "$HOME/.dotfiles/shell/clip.sh" ] && source "$HOME/.dotfiles/shell/clip.sh"

## Per-host terminal colours while SSHed in (map: ~/.ssh/themes)
[ -f "$HOME/.dotfiles/shell/ssh-theme.sh" ] && source "$HOME/.dotfiles/shell/ssh-theme.sh"

## Export ENV variables

# to have cool history with timestamps
export HISTTIMEFORMAT="%y/%m/%d %T "

## ALIASES

alias dotfiles='cd $HOME/.dotfiles'

alias rs='reset'
alias cl='clear'
alias cat="bat --style=auto"
alias ls="eza --icons"
alias l="ls -lah"

# open command for wsl
if command -v explorer.exe >/dev/null 2>&1; then
    alias open='explorer.exe'
fi

# git
alias g='git'

# editors
alias v='vim'
alias vs='code'
alias zd='zed'

if [[ $OS == 'osx' ]]; then
  alias blender="/Applications/Blender/blender.app/Contents/MacOS/blender"
  alias sublime="/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl"
fi

# yarn
alias ya='yarn'

# terraform
alias tf='terraform'

# languages
alias js='node'
alias py='python'
alias rb='ruby'

# agents
alias ccusage='npx ccusage@latest'

# herdr reads one config file, ~/.config/herdr/config.toml, and both the client
# and the brew-managed server read it: the server draws the panes, so their
# borders follow its config. build-config.sh generates it from
# shell/_tools/herdr/config.toml plus ~/.config/herdr/config.local.toml (this
# machine's own overrides, unversioned like ~/.tmux.conf.local, optional), and
# reloads the server when it changes. Rebuilt on every call: edit the sources,
# never the generated files, and relaunch to apply.
#
# Inside tmux, which already owns herdr's ctrl+a prefix, the client alone runs
# on config.effective.toml, the same config with the prefix back on ctrl+b.
#
# `herdr --remote <host>` repaints the window with the host's colours from
# ~/.ssh/themes, the same as `ssh <host>` does (shell/ssh-theme.sh): herdr runs
# ssh itself, so the ssh() wrapper never sees that connection. The local client
# also draws the UI with its own config, so when the host's entry there names a
# flavour with a themes/<flavour>.toml (`my-desktop foxpuccin`), the client runs on
# config.remote-<flavour>.toml: this config with that [theme] in place of ours,
# the one the remote machine itself runs on.
#
# `herdr my-server` is short for `herdr --remote my-server`: a first word that is a Host in
# the ssh config (ssh resolves it to some other hostname) or has a user@ is a
# machine to attach to. herdr's own subcommands resolve to themselves, so
# `herdr status` and friends still reach herdr untouched.
#
# A remote attach runs on the server's keybindings (--remote-keybindings
# server) unless told otherwise. With herdr's default, local, the client drops
# every [[keys.command]], so prefix+x and prefix+a did nothing; the server's
# are the same shared config, and its commands run where the panes are. Inside
# tmux that also means the server's ctrl+a prefix, not ctrl+b.
herdr() {
  local tools="$HOME/.dotfiles/shell/_tools/herdr"
  local conf="$HOME/.config/herdr/config.toml"
  local out="$HOME/.config/herdr/config.effective.toml"
  local remote="" prev="" a flavour keys=""
  local -a run merge

  zsh "$tools/build-config.sh" ||
    echo "herdr: could not merge config, starting on $conf as it is" >&2

  case "$1" in
    ''|-*) ;;
    *@*) set -- --remote "$@" ;;
    *)
      if [ "$(command ssh -G "$1" 2>/dev/null | awk '$1 == "hostname" { print $2 }')" != "$1" ]; then
        set -- --remote "$@"
      fi
      ;;
  esac

  for a in "$@"; do
    case "$a" in
      --remote=*) remote="${a#--remote=}" ;;
      --remote-keybindings|--remote-keybindings=*) keys=1 ;;
      *) [ "$prev" = --remote ] && remote="$a" ;;
    esac
    prev="$a"
  done

  [ -n "$remote" ] && [ -z "$keys" ] && set -- "$@" --remote-keybindings server

  merge=()
  [ -n "$TMUX" ] && merge+=(--prefix ctrl+b)
  if [ -n "$remote" ] && typeset -f _ssh_theme_target >/dev/null; then
    flavour=$(_ssh_theme_target "$remote" --word)
    if [ -n "$flavour" ] && [ -f "$tools/themes/$flavour.toml" ]; then
      merge+=(--theme "$tools/themes/$flavour.toml")
      out="$HOME/.config/herdr/config.remote-$flavour.toml"
    fi
  fi

  run=(command herdr)
  if [ "${#merge[@]}" -gt 0 ] && [ -f "$conf" ] &&
    python3 "$tools/merge-config.py" "$out" "$conf" "${merge[@]}"; then
    run=(env HERDR_CONFIG_PATH="$out" herdr)
  fi

  if [ -n "$remote" ] && typeset -f _ssh_theme_run >/dev/null; then
    _ssh_theme_run "$remote" "${run[@]}" "$@"
    return
  fi
  "${run[@]}" "$@"
}
alias hd='herdr'

# Update Claude Code and restart the idle sessions in herdr onto the new version.
# See shell/_tools/claude/ccupdate.sh.
alias ccupdate='zsh ~/.dotfiles/shell/_tools/claude/ccupdate.sh'

# import packages and tools

# antigen

# Antigen short-circuits on the mere existence of its generated cache, so a
# zero-byte ~/.antigen/init.zsh (an interrupted first run, or two shells racing
# on the `cat >` that truncates it) silently stubs out `antigen` and every
# bundle below becomes a no-op. It never self-heals: the only rebuild trigger is
# a check file being newer than its .zwc. Drop an empty cache before sourcing
# antigen - it has already read the cache by the time `antigen apply` runs.
[[ -f "$HOME/.antigen/init.zsh" && ! -s "$HOME/.antigen/init.zsh" ]] && \
  rm -f "$HOME/.antigen/init.zsh" "$HOME/.antigen/init.zsh.zwc"

[[ -f "/usr/share/zsh/share/antigen.zsh" ]] && source "/usr/share/zsh/share/antigen.zsh"
[[ -f "/usr/local/share/antigen/antigen.zsh" ]] && source "/usr/local/share/antigen/antigen.zsh"
[[ -f "/opt/homebrew/opt/antigen/share/antigen/antigen.zsh" ]] && source "/opt/homebrew/opt/antigen/share/antigen/antigen.zsh"

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-history-substring-search

# https://github.com/zsh-users/zsh-syntax-highlighting/issues/411
zle -N history-substring-search-up
zle -N history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

antigen apply

# zoxide or autojump
if command -v zoxide >/dev/null; then
  if [ -n "$ZSH_VERSION" ]; then
    # Antigen defers compinit to the first precmd and, until it fires, leaves
    # `compdef` stubbed out as an empty function (~/.antigen/init.zsh). Every
    # completion registered from .zshrc -- zoxide's included -- is therefore
    # silently thrown away, and the deferred compinit would rebuild _comps from
    # fpath afterwards anyway. Run compinit here and cancel the deferred one, so
    # the compdef calls below actually stick.
    autoload -Uz add-zsh-hook compinit
    add-zsh-hook -D precmd _antigen_compinit 2>/dev/null
    compinit -i -d "$HOME/.antigen/.zcompdump"
    (( $+functions[_antigen] )) && compdef _antigen antigen
  fi

  eval "$(zoxide init zsh)"

  if [ -n "$ZSH_VERSION" ]; then
    # zoxide ships a completion that only reaches the database on Space-Tab,
    # and only through fzf; plain `z data2<TAB>` just lists subdirectories of
    # the current directory. Complete from the database directly instead, so
    # the keywords you type rank against every folder you have visited.
    _zoxide_db_complete() {
      local -a results
      results=(${(f)"$(command zoxide query --list --exclude "$PWD" -- "${(@)words[2,CURRENT]}" 2>/dev/null)"})
      (( $#results )) || return 1
      # Two defaults have to be overridden to keep zoxide's ranking intact:
      # plain compadd sorts matches alphabetically (-V makes an unsorted group),
      # and the first Tab inserts the longest prefix common to every match --
      # for "data2" that is just /Users/danilojuns/, because cowork/data2 shares
      # nothing else with the development/data2 tree. Menu insertion puts the
      # best-ranked path on the line instead, and further Tabs cycle.
      compstate[insert]=menu
      compadd -U -Q -V zoxide -a results
    }
    compdef _zoxide_db_complete z
  fi
fi
[ -f "/opt/homebrew/etc/profile.d/autojump.sh" ] && . "/opt/homebrew/etc/profile.d/autojump.sh"

# asdf

[[ -f "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"
[[ -f "/opt/asdf-vm/asdf.sh" ]] && source "/opt/asdf-vm/asdf.sh"
[[ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]] && source "/usr/local/opt/asdf/libexec/asdf.sh"
[[ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]] && source "/opt/homebrew/opt/asdf/libexec/asdf.sh"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
