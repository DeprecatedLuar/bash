#!/usr/bin/env bash
# sat shell - temporary environment with auto-cleanup

SAT_RUN_DIR="/tmp/sat-shell"

# Cleanup orphaned sessions from killed shells
cleanup_orphans() {
    [[ ! -d "$SAT_RUN_DIR" ]] && return

    for manifest in "$SAT_RUN_DIR"/*/manifest; do
        [[ ! -f "$manifest" ]] && continue

        local session_dir=$(dirname "$manifest")
        local pid=$(basename "$session_dir")

        if ! kill -0 "$pid" 2>/dev/null; then
            while IFS='=' read -r key value; do
                [[ "$key" == "TOOL" ]] && pkg_remove "$value" "$(grep "^SOURCE_$value=" "$manifest" | cut -d= -f2)"
            done < <(grep "^TOOL=" "$manifest")
            rm -rf "$session_dir"
        fi
    done
}

# Remove package via appropriate method
pkg_remove() {
    local pkg="$1" source="$2"
    [[ -z "$source" ]] && return

    printf "Removing %s..." "$pkg"
    case "$source" in
        apt)    sudo apt remove --purge -y "$pkg" >/dev/null 2>&1 && sudo apt autoremove -y >/dev/null 2>&1 ;;
        apk)    sudo apk del "$pkg" >/dev/null 2>&1 ;;
        pacman) sudo pacman -Rs --noconfirm "$pkg" >/dev/null 2>&1 ;;
        dnf)    sudo dnf remove -y "$pkg" >/dev/null 2>&1 ;;
        pkg)    pkg uninstall -y "$pkg" >/dev/null 2>&1 ;;
        uv)     uv tool uninstall "$pkg" >/dev/null 2>&1 ;;
    esac
    printf "\rRemoved %-30s\n" "$pkg"
}

# Install a single tool, return source on success
install_tool() {
    local tool="$1"
    local pkg_mgr=$(get_pkg_manager)

    # Try uv first for Python CLIs
    if command -v uv &>/dev/null && uv tool install "$tool" >/dev/null 2>&1; then
        echo "uv"
        return 0
    fi

    # Try native package manager
    if [[ -n "$pkg_mgr" ]] && pkg_exists "$tool" "$pkg_mgr"; then
        if pkg_install "$tool" "$pkg_mgr" >/dev/null 2>&1; then
            echo "$pkg_mgr"
            return 0
        fi
    fi

    return 1
}

# Main shell runner
sat_shell() {
    local tools=("$@")

    if [[ ${#tools[@]} -eq 0 ]]; then
        echo "Usage: sat shell <tool> [tool2] [tool3] ..."
        return 1
    fi

    # Cleanup orphans from killed sessions
    cleanup_orphans

    # Session tracking
    local session_dir="$SAT_RUN_DIR/$$"
    local manifest="$session_dir/manifest"
    mkdir -p "$session_dir"

    # Check what needs installing
    local to_install=()
    local already_have=()

    echo "Checking tools..."
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            already_have+=("$tool")
        else
            to_install+=("$tool")
        fi
    done

    # Show plan
    echo ""
    echo "=== sat shell ==="
    [[ ${#already_have[@]} -gt 0 ]] && echo "  Already installed: ${already_have[*]}"
    [[ ${#to_install[@]} -gt 0 ]] && echo "  Will install: ${to_install[*]}"
    echo ""

    # Install missing tools
    local installed=()
    for tool in "${to_install[@]}"; do
        printf "Installing %s..." "$tool"
        local source=$(install_tool "$tool")
        if [[ -n "$source" ]]; then
            printf "\rInstalled %-20s [%s]\n" "$tool" "$source"
            echo "TOOL=$tool" >> "$manifest"
            echo "SOURCE_$tool=$source" >> "$manifest"
            installed+=("$tool")
        else
            printf "\rFailed %-20s\n" "$tool"
        fi
    done

    # Abort if nothing to do
    if [[ ${#installed[@]} -eq 0 && ${#already_have[@]} -eq 0 ]]; then
        echo "No tools available"
        rm -rf "$session_dir"
        return 1
    fi

    # Build tool list for display
    local tool_list=""
    for tool in "${tools[@]}"; do
        local src=$(grep "^SOURCE_$tool=" "$manifest" 2>/dev/null | cut -d= -f2)
        [[ -z "$src" ]] && src="system"
        tool_list+="- $tool [$src]\n"
    done

    # Launch isolated subshell
    SAT_SHELL_TOOLS="${tools[*]}" \
    HISTFILE="$session_dir/history" \
    bash --rcfile <(cat << EOF
source ~/.bashrc 2>/dev/null
export PS1="(sat) \$PS1"
export HISTFILE="$session_dir/history"
export SAT_SESSION="$$"
clear
cols=\$(tput cols 2>/dev/null || echo 80)
header="────[SAT SHELL]"
pad=\$(printf '─%.0s' \$(seq 1 \$((cols - \${#header}))))
echo -e "\033[1m\${header}\${pad}\033[0m"
echo ""
echo -e "$tool_list"
echo "type 'exit' to cleanup and leave"
echo ""
EOF
)

    # Cleanup on exit
    echo ""
    if [[ -f "$manifest" ]]; then
        echo "Cleaning up..."
        while IFS='=' read -r key value; do
            if [[ "$key" == "TOOL" ]]; then
                local src=$(grep "^SOURCE_$value=" "$manifest" | cut -d= -f2)
                pkg_remove "$value" "$src"
            fi
        done < "$manifest"
    fi

    rm -rf "$session_dir"
    echo "sat shell exited"
}
