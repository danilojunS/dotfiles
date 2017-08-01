## Put here are all common alias and scripts for bash and zsh shells

## Detect OS

OS='unknown'
if [[ $(uname) == 'Darwin' ]]; then
  OS='osx'
elif [[ $(uname) == 'Linux' ]]; then
  OS='linux'
fi

## Export ENV variables

# npm settings to allow install global packages without sudo
# https://github.com/sindresorhus/guides/blob/master/npm-global-without-sudo.md
# NPM_PACKAGES="${HOME}/.npm-packages"
# PATH="$PATH:$NPM_PACKAGES/bin"
# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
# unset MANPATH # delete if you already modified MANPATH elsewhere in your config
# export MANPATH="$NPM_PACKAGES/share/man:$(manpath)"

# include global npm modules to node REPL
export NODE_PATH="$NODE_PATH:$HOME/.npm-packages/lib/node_modules"

# pip settings to allow install packages without sudo
# http://kazhack.org/?post/2014/12/12/pip-gem-install-without-sudo
export PYTHONUSERBASE="${HOME}/.pip-packages"
PATH="$PATH:$PYTHONUSERBASE/bin"

# java version to use
export JAVA_HOME="$(/usr/libexec/java_home)"
export STUDIO_JDK="$JAVA_HOME"
# export PATH="/Users/danilojun/.bin:/Users/danilojun/.npm-packages/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/texbin:/Volumes/HDD/Servers/glassfish4/bin"

# to have cool history with timestamps
export HISTTIMEFORMAT="%y/%m/%d %T "

## ALIASES

alias rs='reset'
alias cl='clear'
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

# import packages
[[ -f "$(brew --prefix)/etc/profile.d/z.sh" ]] && . `brew --prefix`/etc/profile.d/z.sh
