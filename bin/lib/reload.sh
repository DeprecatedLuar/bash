#!/bin/bash
# Check core directories exist
if [ ! -d "$TOOLS/bin" ]; then
    echo "Warning: $TOOLS/bin not found. Skipping."
fi

if [ ! -d "$BASHRC/bin" ]; then
    echo "Warning: $BASHRC/bin not found. Skipping."
fi

# Make scripts executable
chmod +x $TOOLS/bin/* 2>/dev/null || true
chmod +x $TOOLS/bin/lib/* 2>/dev/null || true
chmod +x $BASHRC/lib/* 2>/dev/null || true
chmod +x $BASHRC/bin/* 2>/dev/null || true
chmod +x $HOME/bin/sys/* 2>/dev/null || true

# Create ~/bin structure
mkdir -p "$HOME/bin"
mkdir -p "$HOME/bin/lib"
mkdir -p "$HOME/bin/sys"

# Sync symlinks from tools/bin to ~/bin (excluding lib/)
for script in "$TOOLS/bin"/*; do
    [ -e "$script" ] || continue
    [ -d "$script" ] && continue  # Skip directories

    basename=$(basename "$script")
    target="$HOME/bin/$basename"

    # Create/update symlink
    ln -sf "$script" "$target"
done

# Sync symlinks from bashrc/bin to ~/bin (excluding lib/)
for script in "$BASHRC/bin"/*; do
    [ -e "$script" ] || continue
    [ -d "$script" ] && continue  # Skip directories

    basename=$(basename "$script")
    target="$HOME/bin/$basename"

    # Create/update symlink
    ln -sf "$script" "$target"
done

# Sync symlinks from tools/bin/lib to ~/bin/lib
if [ -d "$TOOLS/bin/lib" ]; then
    for lib in "$TOOLS/bin/lib"/*; do
        [ -e "$lib" ] || continue

        basename=$(basename "$lib")
        target="$HOME/bin/lib/$basename"

        ln -sf "$lib" "$target"
    done
fi

# Sync symlinks from bashrc/bin/lib to ~/bin/lib
if [ -d "$BASHRC/bin/lib" ]; then
    for lib in "$BASHRC/bin/lib"/*; do
        [ -e "$lib" ] || continue

        basename=$(basename "$lib")
        target="$HOME/bin/lib/$basename"

        ln -sf "$lib" "$target"
    done
fi

# Remove broken symlinks
find "$HOME/bin" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/lib" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/sys" -maxdepth 1 -xtype l -delete 2>/dev/null || true

# System sync if requested (-s/--system or -h/--hard)
if [[ "$1" == "--system" ]] || [[ "$1" == "-s" ]] || [[ "$1" == "--hard" ]] || [[ "$1" == "-h" ]]; then
    # Sync system-wide scripts
    if [ -d "$HOME/bin/sys" ]; then
        for script in "$HOME/bin/sys"/*; do
            [ -e "$script" ] || continue
            [ -d "$script" ] && continue
            sudo ln -sf "$script" "/usr/local/bin/$(basename "$script")"
        done
    else
        echo "Warning: $HOME/bin/sys not found. Skipping system scripts."
    fi

    # Sync systemd system services
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
