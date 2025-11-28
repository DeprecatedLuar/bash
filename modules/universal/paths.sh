#!/usr/bin/env bash
# PATH configurations

#==================== ENVIRONMENT VARIABLES ====================

#--------------------- SYSTEM DIRECTORIES ----------------------

# Bash config
export BASHRC="$HOME/.config/bash"

# GitHub user
export GITHUB_USER="DeprecatedLuar"

# Home-level standard directories
export BACKUP="$HOME/Backup"
export MEDIA="$HOME/Media"
export DOCUMENTS="$HOME/Documents"
export DOWNLOADS="$HOME/Downloads"
export GAMES="$HOME/Games"

# Media subdirectories
export AUDIO="$MEDIA/Audio"
export PICTURES="$MEDIA/Pictures"
export VIDEOS="$MEDIA/Videos"

#--------------------- WORKSPACE VARS ----------------------

# Workspace root and main directories
export WORKSPACE="$HOME/Workspace"
export TOOLS="$WORKSPACE/tools"
export PROJECTS="$WORKSPACE/projects"
export SHARED="$WORKSPACE/shared"
export SATELLITE="$PROJECTS/cli/the-satellite"

# Tools subdirectories
export TOOLS_FOREIGN="$TOOLS/foreign"
export FOREIGN="$TOOLS/foreign"
export HOMEMADE="$TOOLS/homemade"
export DOCKER_DIR="$TOOLS/docker"

#------------------------ EXTRAS ---------------------------

export QT_QPA_PLATFORMTHEME=qt5ct

#==================== PATH CONFIGURATION ====================

#------------------- UNIVERSAL PATHS ----------------------

export PATH="$HOME/bin:$PATH"
export PATH="$TOOLS_FOREIGN:$PATH"
export PATH="$HOME/.local/bin:$PATH"

#-------------------- DEV TOOLS PATHS ----------------------

# Add dev tools to PATH (environment variables set in .bashrc)
export PATH="$CARGO_HOME/bin:$PATH"           # Rust
export PATH="$GOPATH/bin:$PATH"               # Go
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"    # npm

#==================== TERMINAL & RUNTIME ====================

# export TERM=xterm-256color  # Commented out - let terminal set its own TERM

# Fix terminfo for Nix packages (so they can find kitty's xterm-kitty terminfo)
export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
