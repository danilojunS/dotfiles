#!/bin/sh

# need to be superuser to install things
sudo su

echo "Well, since you are already here, let's make your SSH experience cool!"
echo "Hold your horses..."

# install zsh + oh-my-zsh
yum install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# install utilities
yum install -y htop tmux

# customize .zshrc
echo '

## CUSTOM CHANGES

# add node bin to PATH
export PATH=$PATH:/opt/elasticbeanstalk/node-install/node-v10.15.3-linux-x64/bin

# aliases
alias g="git"
alias v="vim"
alias rs="reset"
alias cl="clear"
alias app="cd /var/app/current"
alias log="tail -f /var/log/nodejs/nodejs.log"

' >> "$HOME/.zshrc"

echo 'You really had to make SSH experience better? 🤔'
echo '[ATTENTION] Superuser has all the good stuff ✌️'

exit