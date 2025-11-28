#!/bin/bash

#--[ENSURE DIRECTORY STRUCTURE]-----------------

source "$BASHRC/bin/lib/ensure-dirs.sh"

#--[CHECK CORE DIRECTORIES]---------------------

if [ ! -d "$TOOLS/bin" ]; then
    echo "Warning: $TOOLS/bin not found. Skipping."
fi

if [ ! -d "$BASHRC/bin" ]; then
    echo "Warning: $BASHRC/bin not found. Skipping."
fi

#--[MAKE SCRIPTS EXECUTABLE]-------------------

chmod +x $TOOLS/bin/* 2>/dev/null || true
chmod +x $TOOLS/bin/lib/* 2>/dev/null || true
chmod +x $BASHRC/bin/* 2>/dev/null || true
chmod +x $BASHRC/bin/lib/* 2>/dev/null || true
chmod +x $HOME/bin/* 2>/dev/null || true
chmod +x $HOME/bin/sys/* 2>/dev/null || true

#--[SYNC BIN SYMLINKS]--------------------------

for script in "$TOOLS/bin"/*; do
    [ -e "$script" ] || continue
    [ -d "$script" ] && continue
    ln -sf "$script" "$HOME/bin/$(basename "$script")"
done

for script in "$BASHRC/bin"/*; do
    [ -e "$script" ] || continue
    [ -d "$script" ] && continue
    ln -sf "$script" "$HOME/bin/$(basename "$script")"
done

#--[SYNC LIB SYMLINKS]-------------------------

ln -sfn "$HOME/.local/bin" "$HOME/bin/local"
ln -sfn "/usr/local/bin" "$HOME/bin/sys/local"

if [ -d "$TOOLS/bin/lib" ]; then
    for lib in "$TOOLS/bin/lib"/*; do
        [ -e "$lib" ] || continue

        basename=$(basename "$lib")
        target="$HOME/bin/lib/$basename"

        ln -sf "$lib" "$target"
    done
fi

if [ -d "$BASHRC/bin/lib" ]; then
    for lib in "$BASHRC/bin/lib"/*; do
        [ -e "$lib" ] || continue

        basename=$(basename "$lib")
        target="$HOME/bin/lib/$basename"

        ln -sf "$lib" "$target"
    done
fi

#--[CLEANUP BROKEN SYMLINKS]--------------------

find "$HOME/bin" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/lib" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/sys" -maxdepth 1 -xtype l -delete 2>/dev/null || true

#--[SYSTEM-LEVEL SYNC]-------------------------

if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]] || [[ "$1" == "--hard" ]] || [[ "$1" == "-h" ]]; then
    if [ -d "$HOME/bin/sys" ]; then
        for script in "$HOME/bin/sys"/*; do
            [ -e "$script" ] || continue
            [ -d "$script" ] && continue
            sudo ln -sf "$script" "/usr/local/bin/$(basename "$script")"
        done
    else
        echo "Warning: $HOME/bin/sys not found. Skipping system scripts."
    fi

    if [ -d "$HOME/.config/systemd/system" ]; then
        for service in "$HOME/.config/systemd/system"/*; do
            [ -e "$service" ] || continue
            [ -d "$service" ] && continue
            sudo ln -sf "$service" "/etc/systemd/system/$(basename "$service")"
        done
        sudo systemctl daemon-reload
    else
        echo "Warning: $HOME/.config/systemd/system not found. Skipping systemd services."
    fi
fi

#--[REFRESH COMMAND HASH]-----------------------

hash -r
