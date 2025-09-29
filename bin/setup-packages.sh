#!/bin/bash
# Package Installation Script - Install essential development tools
# Called by setup.sh after repositories are configured

set -e  # Exit on any error

#=== PACKAGES TO INSTALL ===
# Add/remove packages as needed - one per line
PACKAGES=(
    "zoxide"
    "ranger"
    "curl"
    "wget"
    "git"
    "golang-go"
    "nodejs"
    "micro"
)

echo "Installing essential development tools..."

# Install packages from the list
for package in "${PACKAGES[@]}"; do
    echo "  Installing $package..."
    if ! sudo apt install -y "$package"; then
        echo "      Failed to install $package - skipping"
    fi
done

echo "Package installation complete"
echo "Installed packages: ${PACKAGES[*]}"