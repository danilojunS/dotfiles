#! /bin/bash

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

# installs Vundle (vim plugin manager)
echo -n "Installing Vundle... "
mkdir -p "$HOME/.vim/bundle"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
echo "done!"
