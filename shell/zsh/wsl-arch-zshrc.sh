# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# import packages and tools

source "/usr/share/zsh/share/antigen.zsh"

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-history-substring-search

antigen apply

[[ ! "$(type fasd)" =~ "not found" ]] && eval "$(fasd --init auto)"

source "/opt/asdf-vm/asdf.sh"

## ALIASES

alias rs='reset'
alias cl='clear'
alias dotfiles='cd $HOME/.dotfiles'
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

# tmux init
# tmux attach -t base || tmux new -s base

export PATH="$HOME/.local/bin/:$PATH"

source "$HOME/.customrc"
