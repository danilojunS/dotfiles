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
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
[ -f "/opt/homebrew/etc/profile.d/autojump.sh" ] && . "/opt/homebrew/etc/profile.d/autojump.sh"

# asdf

[[ -f "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"
[[ -f "/opt/asdf-vm/asdf.sh" ]] && source "/opt/asdf-vm/asdf.sh"
[[ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]] && source "/usr/local/opt/asdf/libexec/asdf.sh"
[[ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]] && source "/opt/homebrew/opt/asdf/libexec/asdf.sh"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
