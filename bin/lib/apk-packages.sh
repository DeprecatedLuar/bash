#!/bin/bash

UNIVERSAL=(
    "curl"
    "wget"
    "git"
    "zoxide"
    "ranger"
    "micro"
    "visidata"
)

DEV_TOOLS=(
    "go"
    "nodejs"
)

install_packages() {
    for package in "$@"; do
        echo "Installing $package..."
        sudo apk add "$package" || echo "Failed - skipping"
    done
}
