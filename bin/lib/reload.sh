#!/bin/bash
# Make scripts executable
chmod +x $TOOLS/bin/* 2>/dev/null || true
chmod +x $TOOLS/bin/lib/* 2>/dev/null || true
chmod +x $BASHRC/lib/* 2>/dev/null || true
chmod +x $BASHRC/bin/* 2>/dev/null || true

# Create ~/bin structure
mkdir -p "$HOME/bin"
mkdir -p "$HOME/bin/lib"

# Sync symlinks from tools/bin to ~/bin (excluding lib/)
for script in "$TOOLS/bin"/*; do
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

# Remove broken symlinks
find "$HOME/bin" -maxdepth 1 -xtype l -delete 2>/dev/null || true
find "$HOME/bin/lib" -maxdepth 1 -xtype l -delete 2>/dev/null || true
