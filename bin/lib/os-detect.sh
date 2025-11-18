#!/bin/bash
# OS and package manager detection

detect_os() {
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo "termux"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo "pkg"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v apt &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}
