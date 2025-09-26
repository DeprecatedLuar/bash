#!/bin/bash
# PATH configurations

#------------------- UNIVERSAL PATHS ----------------------

export PATH="$HOME/Documents/Tools/my-scripts:$PATH"
export PATH="$HOME/Documents/Tools/foreign:$PATH"
export PATH="$HOME/.config/bash/modules:$PATH"  # Add your bash scripts
export PATH="$HOME/.local/bin:$PATH"

#-------------------- DEV TOOLS PATHS ----------------------

# Add dev tools to PATH (environment variables set in .bashrc)
export PATH="$CARGO_HOME/bin:$PATH"           # Rust
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"    # npm 
# Go removed - using system installation

#-------------------- SCRIPT PATHS -------------------------

export PATH="$HOME/.config/bash/bin:$PATH"  # Add your bash scripts
export PATH="$HOME/.config/bash/bin/notetaker:$PATH"
export PATH="$HOME/.config/bash/bin/multiplexer:$PATH"

#------------------------ EXTRAS ---------------------------

export TERM=xterm-256color

# Set default editor
export EDITOR=vim
export VISUAL=vim

#--------------------- RUNTIME VARS ------------------------

export CONFIG_918=jIT7yE7lnOJkZgQhuCYcJMf1fiyF9l0ywGk5
