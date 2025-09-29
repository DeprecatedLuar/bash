#!/bin/bash
# Bash Config Setup Script - for deploying to new machines
# Run this script after cloning the bash config folder

echo "Setting up bash configuration and system packages..."

# Step 1: Setup repositories
echo "Step 1: Setting up repositories..."
bash "$HOME/.config/bash/bin/setup-apt-repos.sh"

# Step 2: Create symlinks for shell startup files
echo "Step 2: Creating shell configuration symlinks..."
ln -sf "$HOME/.config/bash/bashrc" "$HOME/.bashrc"
ln -sf "$HOME/.config/bash/profile" "$HOME/.profile"

echo "✅ Created symlinks:"
echo "  ~/.bashrc -> ~/.config/bash/bashrc"
echo "  ~/.profile -> ~/.config/bash/profile"

# Step 3: Install essential system packages
echo "Step 3: Installing essential development tools..."
bash "$HOME/.config/bash/bin/setup-packages.sh"

# Source the new configuration
source "$HOME/.profile"

echo "✅ Setup complete!"
echo "Installed tools:"
echo "  • Bash configuration organized in ~/.config/bash/"
echo "  • Dev tools (cargo, rustup, npm, go) in ~/.config/bash/dev-tools/"
echo "  • Essential tools: zoxide, ranger, micro, go, nodejs"
echo ""
echo "🔄 Please restart your terminal or run: source ~/.bashrc"