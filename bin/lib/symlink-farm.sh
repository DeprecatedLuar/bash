#!/usr/bin/env bash

# Self-healing symlink structure
# Source once - ensures entire symlink farm is correct
# Skips gracefully if directories don't exist

#--[UTILITIES]----------------------------------

setup_sys_local() {
    local user_dir="$1"
    local system_dir="$2"

    [ -d "$user_dir" ] || return 0

    mkdir -p "$user_dir/sys"
    ln -sfn "$system_dir" "$user_dir/sys/local"
}

link_contents() {
    local source_dir="$1"
    local target_dir="$2"

    [ -d "$source_dir" ] || return 0

    for item in "$source_dir"/*; do
        [ -e "$item" ] || continue
        [ -d "$item" ] && continue
        ln -sf "$item" "$target_dir/$(basename "$item")"
    done
}

#--[BIN]----------------------------------------

setup_sys_local "$HOME/bin" "/usr/local/bin"
ln -sfn "$HOME/.local/bin" "$HOME/bin/local" 2>/dev/null || true
link_contents "$TOOLS/bin" "$HOME/bin"
link_contents "$BASHRC/bin" "$HOME/bin"
link_contents "$TOOLS/bin/lib" "$HOME/bin/lib"
link_contents "$BASHRC/bin/lib" "$HOME/bin/lib"

#--[SYSTEMD]------------------------------------

if [ -d "$HOME/.config/systemd" ]; then
    setup_sys_local "$HOME/.config/systemd" "/etc/systemd/system"
    [ -L "$HOME/.config/systemd/user" ] || ln -sf . "$HOME/.config/systemd/user"
fi

#--[AUTOSTART]----------------------------------

setup_sys_local "$HOME/.config/autostart" "/etc/xdg/autostart"

