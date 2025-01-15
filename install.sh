#!/bin/bash

# Exit on any error
set -e

echo "Starting environment setup..."

# 1. Move .tmux.conf to home directory
if [ ! -f ~/.tmux.conf ] || ! cmp -s .tmux.conf ~/.tmux.conf; then
    cp .tmux.conf ~/
    echo "✓ Installed tmux configuration"
fi

# 2. Create ~/.config/nvim directory if it doesn't exist
if [ ! -d ~/.config/nvim ]; then
    mkdir -p ~/.config/nvim
    echo "✓ Created Neovim configuration directory"
fi

# 3. Move init.lua to the correct location
if [ ! -f ~/.config/nvim/init.lua ] || ! cmp -s .config/nvim/init.lua ~/.config/nvim/init.lua; then
    cp .config/nvim/init.lua ~/.config/nvim/
    echo "✓ Installed Neovim configuration"
fi

echo "Installation complete! 🎉"
