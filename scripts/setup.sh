#! /bin/zsh

# Oh My Zsh
echo -n "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
rm "$HOME/.zshrc" # remove automatically created .zshrc
echo "done!"

# Creates the symlinks of all files *.symlink
# The symlinks are created in the $HOME directory

echo -n "Creating symlinks... "
FILES=$(find "$HOME/.dotfiles" -name "*.symlink")
SYMLINKS=$(find "$HOME/.dotfiles" -name "*.symlink" | sed -e "s/.symlink//g" | sed -e "s/.*\//./g")
FILES=(${FILES// / })
SYMLINKS=(${SYMLINKS// / })
for index in "${!FILES[@]}"
do
  ln -s "${FILES[index]}" "$HOME/${SYMLINKS[index]}"
done
echo "done!"

# Homebrew
echo -n "Installing Homebrew..."
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
echo "done!"

# Homebrew installed packages
echo -n "Installing Homebrew packages..."

brew install powerlevel10k
brew install tmux
brew install diff-so-fancy
brew install antigen
brew install asdf
brew install fasd
brew install htop
brew install the_silver_searcher
brew install watchman
brew install exa
brew install bat

brew install terraform

# brew install redis
# brew install sqlite
# brew install opencv
echo -n "done!"

# echo -n "Installing bash-it..."
# git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
# echo "done!"

# installs Vundle (vim plugin manager)
# echo -n "Installing Vundle... "
# mkdir -p "$HOME/.vim/bundle"
# git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
# echo "done!"
