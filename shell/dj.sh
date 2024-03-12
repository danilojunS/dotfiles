## Put here are all common alias and scripts for bash and zsh shells

## Detect OS

OS='unknown'
if [[ $(uname) == 'Darwin' ]]; then
  OS='osx'
elif [[ $(uname) == 'Linux' ]]; then
  OS='linux'
fi

## Export ENV variables

# to have cool history with timestamps
export HISTTIMEFORMAT="%y/%m/%d %T "

## ALIASES

alias dotfiles='cd $HOME/.dotfiles'

alias rs='reset'
alias cl='clear'
alias cat="bat --style=auto"
alias ls="exa --icons"
alias l="ls -lah"

# git
alias g='git'

# vim
alias v='vim'

if [[ $OS == 'osx' ]]; then
  alias blender="/Applications/Blender/blender.app/Contents/MacOS/blender"
  alias sublime="/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl"
fi

# vscode
alias vs='code'

# yarn
alias ya='yarn'

# terraform
alias tf='terraform'

# languages
alias js='node'
alias py='python'
alias rb='ruby'

# import packages and tools

# antigen
[[ -f "/usr/share/zsh/share/antigen.zsh" ]] && source "/usr/share/zsh/share/antigen.zsh"
[[ -f "/usr/local/share/antigen/antigen.zsh" ]] && source "/usr/local/share/antigen/antigen.zsh"

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-history-substring-search

# https://github.com/zsh-users/zsh-syntax-highlighting/issues/411
zle -N history-substring-search-up
zle -N history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

antigen apply

# fasd
[[ ! "$(type fasd)" =~ "not found" ]] && eval "$(fasd --init auto)"

# asdf
[[ -f "/opt/asdf-vm/asdf.sh" ]] && source "/opt/asdf-vm/asdf.sh"
[[ -f "/usr/local/opt/asdf/libexec/asdf.sh" ]] && source "/usr/local/opt/asdf/libexec/asdf.sh"