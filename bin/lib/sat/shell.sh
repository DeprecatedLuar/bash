#!/usr/bin/env bash
# sat shell - temporary environment with auto-cleanup
# Note: SAT_RUN_DIR, SAT_SHELL_MASTER defined in common.sh

# Master manifest helpers (format: tool:source:pid per line)
master_add() {
    local tool="$1" source="$2" pid="$3"
    echo "$tool:$source:$pid" >> "$SAT_SHELL_MASTER"
}

master_remove_pid() {
    local pid="$1"
    [[ -f "$SAT_SHELL_MASTER" ]] && sed -i "/:$pid\$/d" "$SAT_SHELL_MASTER"
}

master_tool_has_other_live_pids() {
    local tool="$1" our_pid="$2"
    [[ ! -f "$SAT_SHELL_MASTER" ]] && return 1
    while IFS=: read -r t src pid; do
        [[ "$t" != "$tool" ]] && continue
        [[ "$pid" == "$our_pid" ]] && continue
        kill -0 "$pid" 2>/dev/null && return 0
    done < "$SAT_SHELL_MASTER"
    return 1
}

master_get_source() {
    local tool="$1"
    [[ -f "$SAT_SHELL_MASTER" ]] && grep "^$tool:" "$SAT_SHELL_MASTER" | head -1 | cut -d: -f2
}

# Cleanup dead entries from master manifest and uninstall orphaned tools
cleanup_master() {
    [[ ! -f "$SAT_SHELL_MASTER" ]] && return
    local temp=$(mktemp)
    while IFS=: read -r tool source pid; do
        [[ -z "$tool" ]] && continue
        if kill -0 "$pid" 2>/dev/null; then
            # PID alive, keep entry
            echo "$tool:$source:$pid" >> "$temp"
        else
            # PID dead - check if other sessions need it or if permanently tracked
            if ! master_tool_has_other_live_pids "$tool" "$pid" && [[ -z "$(manifest_get "$tool")" ]]; then
                pkg_remove "$tool" "$source" >/dev/null 2>&1
            fi
        fi
    done < "$SAT_SHELL_MASTER"
    mv "$temp" "$SAT_SHELL_MASTER"
    # Also clean orphan session dirs
    if [[ -d "$SAT_RUN_DIR" ]]; then
        for dir in "$SAT_RUN_DIR"/*/; do
            [[ ! -d "$dir" ]] && continue
            local pid=$(basename "$dir")
            kill -0 "$pid" 2>/dev/null || rm -rf "$dir"
        done
    fi
}

# Remove package (shell version - with progress output)
shell_pkg_remove() {
    local pkg="$1" source="$2"
    [[ -z "$source" ]] && return

    printf "Removing %s..." "$pkg"
    pkg_remove "$pkg" "$source" >/dev/null 2>&1
    printf "\rRemoved %-30s\n" "$pkg"
}

# Install a single tool, return source on success
# Follows INSTALL_ORDER from common.sh
install_tool() {
    local tool="$1"
    local pkg_mgr=$(get_pkg_manager)

    for source in "${INSTALL_ORDER[@]}"; do
        case "$source" in
            cargo)
                if command -v cargo &>/dev/null && cargo install "$tool" >/dev/null 2>&1; then
                    echo "cargo"
                    return 0
                fi
                ;;
            uv)
                if command -v uv &>/dev/null && uv tool install "$tool" >/dev/null 2>&1; then
                    echo "uv"
                    return 0
                fi
                ;;
            npm)
                if command -v npm &>/dev/null && npm show "$tool" >/dev/null 2>&1; then
                    if npm install -g "$tool" >/dev/null 2>&1; then
                        echo "npm"
                        return 0
                    fi
                fi
                ;;
            system)
                if [[ -n "$pkg_mgr" ]] && pkg_exists "$tool" "$pkg_mgr"; then
                    if pkg_install "$tool" "$pkg_mgr" >/dev/null 2>&1; then
                        echo "$pkg_mgr"
                        return 0
                    fi
                fi
                ;;
            wrapper)
                if curl -sSL --fail --head "$SAT_BASE/cargo-bay/programs/${tool}.sh" >/dev/null 2>&1; then
                    source <(curl -sSL "$SAT_BASE/internal/fetcher.sh")
                    sat_init
                    if sat_run "$tool" >/dev/null 2>&1; then
                        echo "wrapper"
                        return 0
                    fi
                fi
                ;;
        esac
    done

    return 1
}

# Main shell runner
sat_shell() {
    local tools=("$@")

    if [[ ${#tools[@]} -eq 0 ]]; then
        echo "Usage: sat shell <tool> [tool2] [tool3] ..."
        return 1
    fi

    # Cleanup dead sessions from master manifest
    cleanup_master
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
            local display=$(source_display "$source")
            local light=$(source_light "$source")
            local color=$(source_color "$display")
            printf "\r${light}%-20s${C_RESET} [${color}%s${C_RESET}]\n" "$tool" "$display"
            echo "TOOL=$tool" >> "$manifest"
            echo "SOURCE_$tool=$source" >> "$manifest"
            master_add "$tool" "$source" "$$"
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

    # Build tool list for display (with colors)
    # Uses layered source detection: session manifest -> system manifest -> binary path
    local tool_list=""
    for tool in "${tools[@]}"; do
        local src=$(resolve_source "$tool" "$manifest")
        local display=$(source_display "$src")
        local light=$(source_light "$src")
        local color=$(source_color "$display")
        tool_list+="${light}${tool}${C_RESET} [${color}${display}${C_RESET}]\n"
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
                # Skip if another active session needs this tool
                if master_tool_has_other_live_pids "$value" "$$"; then
                    printf "Keeping %-25s (used by another session)\n" "$value"
                    continue
                fi
                local src=$(grep "^SOURCE_$value=" "$manifest" | cut -d= -f2)
                # Skip if permanently tracked with SAME source
                local tracked_src=$(manifest_get "$value")
                if [[ -n "$tracked_src" && "$tracked_src" == "$src" ]]; then
                    printf "Keeping %-25s (permanently tracked)\n" "$value"
                    continue
                fi
                shell_pkg_remove "$value" "$src"
            fi
        done < "$manifest"
        # Remove our entries from master
        master_remove_pid "$$"
    fi

    rm -rf "$session_dir"
    echo "sat shell exited"
}
