## Put here are all common alias and scripts for bash and zsh shells

## Detect OS

OS='unknown'
if [[ $(uname) == 'Darwin' ]]; then
  OS='osx'
elif [[ $(uname) == 'Linux' ]]; then
  OS='linux'
fi

## Export ENV variables

# node settings
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export NODE_PATH="$(npm root -g)"

# go settings
[[ ! "$(type go)" =~ "not found" ]] && PATH="$PATH:$(go env GOPATH)/bin"

# python settings
[[ ! "$(type pyenv)" =~ "not found" ]] && eval "$(pyenv init -)" && eval "$(pyenv virtualenv-init -)"
# export PYTHONUSERBASE="${HOME}/.pip-packages"
# PATH="$PATH:$PYTHONUSERBASE/bin"
export PYENV_VIRTUALENV_DISABLE_PROMPT=1

# ruby settings
export RVM_DIR="$HOME/.rvm"
[ -s "$RVM_DIR/scripts/rvm" ] && source "$RVM_DIR/scripts/rvm"

# java version to use
export JAVA_HOME="$(/usr/libexec/java_home)"
export STUDIO_JDK="$JAVA_HOME"

# to have cool history with timestamps
export HISTTIMEFORMAT="%y/%m/%d %T "

## ALIASES

alias rs='reset'
alias cl='clear'
alias dotfiles='cd $HOME/.dotfiles'

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
[[ ! "$(type fasd)" =~ "not found" ]] && eval "$(fasd --init auto)"
