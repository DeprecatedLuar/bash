#!/bin/bash
# Bash Config Setup Script - for deploying to new machines
# Run this script after cloning the bash config folder

echo "Setting up bash configuration..."

# Create symlinks for shell startup files
ln -sf "$HOME/.config/bash/bashrc" "$HOME/.bashrc"
ln -sf "$HOME/.config/bash/profile" "$HOME/.profile"

echo "✅ Created symlinks:"
echo "  ~/.bashrc -> ~/.config/bash/bashrc"
echo "  ~/.profile -> ~/.config/bash/profile"

# Source the new configuration
source "$HOME/.profile"

echo "✅ Bash configuration setup complete!"
echo "Your dev tools (cargo, rustup, npm) are now organized in ~/.config/bash/dev-tools/"