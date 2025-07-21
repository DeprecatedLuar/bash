#!/bin/bash
# PATH configurations

#------------------- UNIVERSAL PATHS ----------------------

export PATH="$HOME/Documents/Dev/software:$PATH"
export PATH="$HOME/.config/bash/modules:$PATH"  # Add your bash scripts
export PATH="$HOME/.local/bin:$PATH"

#-------------------- SCRIPT PATHS -------------------------

export PATH="$HOME/.config/bash/bin:$PATH"  # Add your bash scripts
export PATH="$HOME/.config/bash/bin/notetaker:$PATH"
export PATH="$HOME/.config/bash/bin/multiplexer:$PATH"

#------------------------ EXTRAS ---------------------------

export TERM=xterm-256color

# Set default editor
export EDITOR=vim
export VISUAL=vim
