#!/usr/bin/env bash
# Bash config bootstrap - curl one-liner installer

set -e

TARGET="$HOME/.config/bash"
REPO="https://github.com/DeprecatedLuar/bash.git"

command -v git >/dev/null || { echo "Error: git required"; exit 1; }

mkdir -p "$HOME/.config"

if [ -d "$TARGET/.git" ]; then
    git -C "$TARGET" pull
else
    rm -rf "$TARGET"
    git clone "$REPO" "$TARGET"
fi

ln -sf "$TARGET/bashrc" "$HOME/.bashrc"
ln -sf "$TARGET/profile" "$HOME/.profile"

echo "Done. Run: source ~/.bashrc"
