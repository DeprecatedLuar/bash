#!/bin/bash
# Initialize workspace folder structure

# Source workspace variables
source "$HOME/.config/bash/modules/universal/paths.sh"

echo "Creating workspace structure..."
mkdir -p "$PROJECTS"
mkdir -p "$TOOLS/bin/lib"
mkdir -p "$TOOLS/bin/completions"
mkdir -p "$TOOLS_FOREIGN"
mkdir -p "$HOMEMADE"
mkdir -p "$DOCKER_DIR"
echo "Workspace structure created at $WORKSPACE_ROOT"