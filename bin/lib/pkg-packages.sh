#!/bin/bash

UNIVERSAL=(
    "termux-tools"
    "git"
    "curl"
    "wget"
    "openssh"
    "zoxide"
    "ranger"
    "micro"
    "visidata"
    "starship"
    "ncdu"
    "btop"
)

DEV_TOOLS=(
    "nodejs-lts"
    "python"
    "golang"
)

install_packages() {
    for package in "$@"; do
        echo "Installing $package..."
        pkg install -y "$package" || echo "Failed - skipping"
    done
}
