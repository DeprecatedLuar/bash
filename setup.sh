#!/bin/bash
# Bash Config Setup Script
# Interactive setup for bash configuration

echo "Running interactive setup..."
echo ""

# Step 1: Workspace structure
read -p "Create workspace structure? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Source paths for GITHUB_USER variable
    source "$HOME/.config/bash/modules/universal/paths.sh"
    curl -sSL "https://raw.githubusercontent.com/$GITHUB_USER/the-satellite/main/satellite.sh" | bash -s -- init-workspace
fi

# Step 2: Shell symlinks
read -p "Create/update shell symlinks (~/.bashrc, ~/.profile)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ln -sf "$HOME/.config/bash/bashrc" "$HOME/.bashrc"
    ln -sf "$HOME/.config/bash/profile" "$HOME/.profile"
    echo "✓ Created symlinks"
fi

# Step 3: Install dotfiles
read -p "Install dotfiles? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing dotfiles..."

    # Clone dots repo to ~/.config/dots
    if [ ! -d "$HOME/.config/dots" ]; then
        echo "Cloning dots repository..."
        git clone https://github.com/DeprecatedLuar/dots.git "$HOME/.config/dots"
    elif [ -z "$(ls -A "$HOME/.config/dots" 2>/dev/null)" ]; then
        echo "Dots directory is empty, cloning..."
        git clone https://github.com/DeprecatedLuar/dots.git "$HOME/.config/dots"
    else
        echo "Dots repo already exists, skipping clone"
    fi

    # Install dots CLI tool
    curl -sSL https://raw.githubusercontent.com/DeprecatedLuar/ireallylovemydots/main/install.sh | bash
fi

# Step 4: Detect OS for package management
source "$HOME/.config/bash/bin/lib/os-detect.sh"
PKG_MGR=$(detect_package_manager)

# Step 5: Setup repositories (apt only)
if [[ "$PKG_MGR" == "apt" ]]; then
    read -p "Setup package repositories? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$HOME/.config/bash/bin/lib/apt-repos.sh"
    fi
fi

# Step 6: Install universal packages
if [[ -f "$HOME/.config/bash/bin/lib/${PKG_MGR}-packages.sh" ]]; then
    read -p "Install universal packages? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        source "$HOME/.config/bash/bin/lib/${PKG_MGR}-packages.sh"
        install_packages "${UNIVERSAL[@]}"
    fi

    # Step 7: Install dev tools
    read -p "Install dev tools? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        source "$HOME/.config/bash/bin/lib/${PKG_MGR}-packages.sh"
        install_packages "${DEV_TOOLS[@]}"
    fi
fi

echo ""
echo "✓ Setup complete!"
echo "Run 'reload' to apply changes"
