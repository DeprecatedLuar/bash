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

#--[SSH KEY SETUP]-----------------------------

ln -sf "$BASHRC/modules/universal/.noruelga.pub" "$HOME/.ssh/noruelga.pub"

#--[SYSTEM-LEVEL SYNC]-------------------------

sync_to_system() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    if [ -d "$source_dir" ]; then
        for item in "$source_dir"/*; do
            [ -e "$item" ] || continue
            [ -d "$item" ] && continue
            sudo ln -sf "$item" "$target_dir/$(basename "$item")"
        done
    else
        echo "Warning: $source_dir not found. Skipping $label."
    fi
}

if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]] || [[ "$1" == "--hard" ]] || [[ "$1" == "-h" ]]; then
    sync_to_system "$HOME/bin/sys" "/usr/local/bin" "system scripts"
    sync_to_system "$HOME/.config/systemd/sys" "/etc/systemd/system" "systemd services"
    sync_to_system "$HOME/.config/autostart/sys" "/etc/xdg/autostart" "autostart entries"
    sync_to_system "$HOME/.local/share/applications/sys" "/usr/share/applications" "desktop entries"

    if [[ -n "$NORUELGA" ]]; then
        sudo mkdir -p /root/.ssh
        sudo cp "$BASHRC/modules/universal/.noruelga.pub" /root/.ssh/authorized_keys
        sudo chmod 700 /root/.ssh
        sudo chmod 600 /root/.ssh/authorized_keys
    fi

    sudo systemctl daemon-reload
fi

#--[REFRESH COMMAND HASH]-----------------------

hash -r
