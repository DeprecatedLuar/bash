#!/bin/bash
# Repository Setup Script - Enable additional Ubuntu repositories
# Called by setup.sh

set -e  # Exit on any error

echo "Setting up repositories..."

# Enable universe repository (for zoxide, ranger and other packages)
echo "  Enabling universe repository..."
sudo add-apt-repository universe -y

# Enable multiverse repository (for additional software)
echo "  Enabling multiverse repository..."
sudo add-apt-repository multiverse -y

# Add Go backports PPA for latest Go version
echo "  Adding Go backports PPA..."
sudo add-apt-repository ppa:longsleep/golang-backports -y

# Add NodeSource PPA for latest Node.js LTS
echo "  Adding NodeSource PPA..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

# Add PostgreSQL official repository for latest versions
echo "  Adding PostgreSQL official repository..."
sudo apt install -y curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Add OBS Studio PPA
echo "  Adding OBS Studio PPA..."
sudo add-apt-repository ppa:obsproject/obs-studio -y

# Update package list after adding all PPAs
echo "  Updating package lists..."
sudo apt update

echo "Repository setup complete!"