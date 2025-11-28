#!/bin/bash
# Bash config bootstrap - curl one-liner installer

TARGET="$HOME/.config/bash"
REPO="https://github.com/AS-Luar/bash.git"

git clone "$REPO" "$TARGET" 2>/dev/null || git -C "$TARGET" pull

ln -sf "$TARGET/bashrc" "$HOME/.bashrc"
ln -sf "$TARGET/profile" "$HOME/.profile"

echo "Done. Run: source ~/.bashrc"
