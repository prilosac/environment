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
if [ ! -d ~/.config/nvim/lua/plugins ]; then
    mkdir -p ~/.config/nvim/lua/plugins
    echo "✓ Created Neovim configuration directory"
fi

# 3. Move init.lua to the correct location
if [ ! -f ~/.config/nvim/init.lua ] || ! cmp -s .config/nvim/init.lua ~/.config/nvim/init.lua; then
    cp .config/nvim/init.lua ~/.config/nvim/
    echo "✓ Installed Neovim configuration"
fi
#
# 3. Move plugins/ai.lua to the correct location
if [ ! -f ~/.config/nvim/lua/plugins/ai.lua ] || ! cmp -s .config/nvim/lua/plugins/ai.lua ~/.config/nvim/lua/plugins/ai.lua; then
    cp .config/nvim/lua/plugins/ai.lua ~/.config/nvim/lua/plugins
    echo "✓ Installed custom 'ai' plugin configuration"
fi

echo "🎉 Installation complete!"
