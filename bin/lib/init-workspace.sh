#!/bin/bash
# Initialize complete directory structure

# Source workspace variables
source "$HOME/.config/bash/modules/universal/paths.sh"

echo "Creating home directory structure..."

# Home-level directories
mkdir -p "$BACKUP"
mkdir -p "$AUDIO"
mkdir -p "$PICTURES"
mkdir -p "$VIDEOS"
mkdir -p "$DOCUMENTS"
mkdir -p "$DOWNLOADS"
mkdir -p "$GAMES"

# Home-level symlinks
ln -sf "./.config" "$HOME/Config"
ln -sf "./.local" "$HOME/Local"

echo "Creating workspace structure..."

# Workspace structure
mkdir -p "$PROJECTS"
mkdir -p "$SHARED"
mkdir -p "$TOOLS/bin/lib"
mkdir -p "$TOOLS/bin/completions"
mkdir -p "$TOOLS_FOREIGN"
mkdir -p "$HOMEMADE"
mkdir -p "$DOCKER_DIR"

# Create ~/bin directory structure
mkdir -p "$HOME/bin"
mkdir -p "$HOME/bin/lib"

# Create convenience symlink
ln -sf "$HOME/.local/bin" "$HOME/bin/local"

echo "✓ Complete directory structure created"