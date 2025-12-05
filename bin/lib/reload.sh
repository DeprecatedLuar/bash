#!/usr/bin/env bash

#--[ENSURE DIRECTORY STRUCTURE]-----------------

source "$BASHRC/bin/lib/ensure-dirs.sh"

#--[MAKE SCRIPTS EXECUTABLE]-------------------

chmod +x $TOOLS/bin/* 2>/dev/null || true
chmod +x $TOOLS/bin/lib/* 2>/dev/null || true
chmod +x $BASHRC/bin/* 2>/dev/null || true
chmod +x $BASHRC/bin/lib/* 2>/dev/null || true
chmod +x $HOME/bin/* 2>/dev/null || true
chmod +x $HOME/bin/sys/* 2>/dev/null || true

#--[SYNC SYMLINKS]-----------------------------

source "$BASHRC/bin/lib/symlink-farm.sh"
ln -sf "$BASHRC/modules/defaults/mimeapps.list" "$HOME/.config/mimeapps.list"

#--[CLEANUP BROKEN SYMLINKS]--------------------

find "$HOME/bin" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/lib" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/sys" -maxdepth 1 -xtype l -delete 2>/dev/null || true

#--[SYSTEM-LEVEL SYNC]-------------------------

if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]] || [[ "$1" == "--hard" ]] || [[ "$1" == "-h" ]]; then
    sync_system_links
fi

#--[ENSURE KITTY TERMINFO]---------------------

if ! infocmp xterm-kitty &>/dev/null; then
    if ! sat install kitty-terminfo:sys 2>/dev/null; then
        export TERM=xterm-256color
    fi
fi

#--[REFRESH COMMAND HASH]-----------------------

hash -r
