## Put here  are all common alias and scripts for bash and zsh shells

## Detect OS

OS='unknown'
if [[ $(uname) == 'Darwin' ]]; then
  OS='osx'
elif [[ $(uname) == 'Linux' ]]; then
  OS='linux'
fi

## Export ENV variables

export PATH="/Users/danilojun/.bin:/Users/danilojun/.npm-packages/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/texbin:/Volumes/HDD/Servers/glassfish4/bin"
export JAVA_HOME=$(/usr/libexec/java_home)
export STUDIO_JDK=$JAVA_HOME

## ALIASES

alias rs='reset'
alias dotfiles='cd $HOME/.dotfiles'

# git
alias g='git'
alias s='git status'
alias p='git push'
alias u='git pull'

# vim
alias v='vim'

if [[ $OS == 'osx' ]]; then
  alias blender="/Applications/Blender/blender.app/Contents/MacOS/blender"
  alias sublime="/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl"
fi

