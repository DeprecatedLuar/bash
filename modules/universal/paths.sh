#!/bin/bash
# PATH configurations

#==================== ENVIRONMENT VARIABLES ====================

#--------------------- WORKSPACE VARS ----------------------

# Bash folder
export BASHRC="$HOME/.config/bash"

# Standard workspace locations
export WORKSPACE_ROOT="$HOME/Workspace"
export TOOLS="$WORKSPACE_ROOT/tools"
export PROJECTS="$WORKSPACE_ROOT/projects"

# Tools subdirectories
export TOOLS_FOREIGN="$TOOLS/foreign"
export FOREIGN="$TOOLS/foreign"
export HOMEMADE="$TOOLS/homemade"
export DOCKER_DIR="$TOOLS/docker"

#------------------------ EXTRAS ---------------------------

export QT_QPA_PLATFORMTHEME=qt5ct

#==================== PATH CONFIGURATION ====================

#------------------- UNIVERSAL PATHS ----------------------

export PATH="$TOOLS/bin:$PATH"
export PATH="$TOOLS_FOREIGN:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$BASHRC/bin:$PATH"

#-------------------- DEV TOOLS PATHS ----------------------

# Add dev tools to PATH (environment variables set in .bashrc)
export PATH="$CARGO_HOME/bin:$PATH"           # Rust
export PATH="$GOPATH/bin:$PATH"               # Go
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"    # npm

#==================== TERMINAL & RUNTIME ====================

# export TERM=xterm-256color  # Commented out - let terminal set its own TERM

# Fix terminfo for Nix packages (so they can find kitty's xterm-kitty terminfo)
export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
