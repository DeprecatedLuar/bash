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

# =============================================================================
# CLEANUP FUNCTION - Called when sat shell exits
# =============================================================================
shell_cleanup() {
    local session_pid="$1"
    local session_dir="$2"
    local session_manifest="$session_dir/manifest"

    echo ""
    printf "${C_DIM}Cleaning up session $session_pid${C_RESET}\n"

    # 1. READ session manifest - what did WE install?
    if [[ ! -f "$session_manifest" ]]; then
        echo "  No tools installed"
        rm -rf "$session_dir"
        return 0
    fi

    local -a session_tools=()
    local -A session_sources=()

    while IFS='=' read -r key value; do
        if [[ "$key" == "TOOL" ]]; then
            session_tools+=("$value")
        elif [[ "$key" == SOURCE_* ]]; then
            local tool="${key#SOURCE_}"
            session_sources["$tool"]="$value"
        fi
    done < "$session_manifest"

    if [[ ${#session_tools[@]} -eq 0 ]]; then
        echo "  Nothing to remove"
        rm -rf "$session_dir"
        return 0
    fi

    # 2. FILTER - determine what to actually remove
    local -a to_remove=()
    local -a to_keep=()

    for tool in "${session_tools[@]}"; do
        local dominated source="${session_sources[$tool]}"

        # Check if other LIVE sessions need this tool
        if master_tool_has_other_live_pids "$tool" "$session_pid"; then
            to_keep+=("$tool (other session)")
            continue
        fi

        # Check if permanently tracked in system manifest
        local tracked_src=$(manifest_get "$tool")
        if [[ -n "$tracked_src" ]]; then
            to_keep+=("$tool (permanent)")
            continue
        fi

        to_remove+=("$tool")
    done

    # Show what we're keeping
    for kept in "${to_keep[@]}"; do
        printf "  ${C_DIM}~ %s${C_RESET}\n" "$kept"
    done

    # 3. ATOMIC REMOVAL LOOP
    if [[ ${#to_remove[@]} -gt 0 ]]; then
        for tool in "${to_remove[@]}"; do
            local src="${session_sources[$tool]}"
            local display=$(source_display "$src")
            local color=$(source_color "$display")

            pkg_remove "$tool" "$src" >/dev/null 2>&1 &
            spin_probe "$tool" $!
            if wait $!; then
                sed -i "/^${tool}:.*:${session_pid}$/d" "$SAT_SHELL_MASTER"
                printf "  - %-18s [${color}%s${C_RESET}]\n" "$tool" "$display"
            else
                printf "  ${C_CROSS} %-18s ${C_DIM}(failed)${C_RESET}\n" "$tool"
            fi
        done
    else
        echo "  Nothing to remove"
    fi

    # 4. DELETE temp session dir
    rm -rf "$session_dir"
}

# Main shell runner
sat_shell() {
    local specs=("$@")

    if [[ ${#specs[@]} -eq 0 ]]; then
        echo "Usage: sat shell <tool[:source]> [tool2[:source]] ..."
        return 1
    fi

    # Cleanup dead sessions from master manifest
    cleanup_master
    local session_dir="$SAT_RUN_DIR/$$"
    local manifest="$session_dir/manifest"
    mkdir -p "$session_dir"

    # Check what needs installing (parse specs to get tool names)
    local to_install=()
    local already_have=()

    for spec in "${specs[@]}"; do
        parse_tool_spec "$spec"
        local tool="$_TOOL_NAME"
        local forced_src="$_TOOL_SOURCE"

        # If source specified, always install (user wants that specific version)
        # If no source and tool exists, skip
        if [[ -z "$forced_src" ]] && command -v "$tool" &>/dev/null; then
            already_have+=("$spec")
        else
            to_install+=("$spec")
        fi
    done

    # Convert arrays to strings for embedding in rcfile
    local to_install_str="${to_install[*]}"
    local already_have_str="${already_have[*]}"
    local all_specs_str="${specs[*]}"

    # Write rcfile that does install inside tmux
    local rcfile="$session_dir/rcfile"
    cat > "$rcfile" << 'RCFILE_START'
source ~/.bashrc 2>/dev/null
RCFILE_START

    cat >> "$rcfile" << RCFILE_VARS
export PS1="(sat) \$PS1"
export HISTFILE="$session_dir/history"
export SAT_SESSION="$$"

# Session paths
SAT_MANIFEST="$manifest"
SAT_SHELL_MASTER="$SAT_SHELL_MASTER"

# Tool specs (may include :source suffix)
SAT_TO_INSTALL=($to_install_str)
SAT_ALREADY_HAVE=($already_have_str)
SAT_ALL_SPECS=($all_specs_str)
RCFILE_VARS

    cat >> "$rcfile" << 'RCFILE_MAIN'

# Source sat common for install functions
source "$HOME/.config/bash/bin/lib/sat/common.sh"

# Use shell-specific install order (no sudo preferred)
INSTALL_ORDER=("${SHELL_INSTALL_ORDER[@]}")

# Master manifest helper
_master_add() {
    echo "$1:$2:$SAT_SESSION" >> "$SAT_SHELL_MASTER"
}

clear
cols=$(tput cols 2>/dev/null || echo 80)
header="────[SAT SHELL]"
pad=$(printf '─%.0s' $(seq 1 $((cols - ${#header}))))
echo -e "\033[1m${header}${pad}\033[0m"
echo ""

# Show already installed tools first (muted)
for spec in "${SAT_ALREADY_HAVE[@]}"; do
    parse_tool_spec "$spec"
    tool="$_TOOL_NAME"
    src=$(detect_source "$tool")
    display=$(source_display "$src")
    light=$(source_light "$src")
    color=$(source_color "$display")
    printf "[${C_CHECK}] ${light}%-20s${C_RESET} [${color}%s${C_RESET}] ${C_DIM}(already installed)${C_RESET}\n" "$tool" "$display"
done

# Install missing tools with animation
if [[ ${#SAT_TO_INSTALL[@]} -gt 0 ]]; then
    total=${#SAT_TO_INSTALL[@]}

    # Print initial list
    for spec in "${SAT_TO_INSTALL[@]}"; do
        parse_tool_spec "$spec"
        printf "[ ] %s\n" "$_TOOL_NAME"
    done

    # Move cursor back up
    printf "\033[%dA" "$total"

    # Install each tool
    for spec in "${SAT_TO_INSTALL[@]}"; do
        parse_tool_spec "$spec"
        tool="$_TOOL_NAME"
        forced_src="$_TOOL_SOURCE"

        # Use forced source or fallback chain
        if [[ -n "$forced_src" ]]; then
            try_source "$tool" "$forced_src" &
            spin_probe "$tool" $!
            if wait $!; then
                _INSTALL_SOURCE="$forced_src"
                installed=true
            else
                installed=false
            fi
        else
            installed=false
            install_with_fallback "$tool" && installed=true
        fi

        if $installed; then
            display=$(source_display "$_INSTALL_SOURCE")
            light=$(source_light "$_INSTALL_SOURCE")
            color=$(source_color "$display")
            printf "\r[${C_CHECK}] ${light}%-20s${C_RESET} [${color}%s${C_RESET}]\n" "$tool" "$display"
            echo "TOOL=$tool" >> "$SAT_MANIFEST"
            echo "SOURCE_$tool=$_INSTALL_SOURCE" >> "$SAT_MANIFEST"
            _master_add "$tool" "$_INSTALL_SOURCE"
        else
            printf "\r[${C_CROSS}] %-20s\n" "$tool"
        fi
    done

    # Check for dependency-installed tools
    for spec in "${SAT_TO_INSTALL[@]}"; do
        parse_tool_spec "$spec"
        tool="$_TOOL_NAME"
        if command -v "$tool" &>/dev/null && ! grep -q "^TOOL=$tool$" "$SAT_MANIFEST" 2>/dev/null; then
            src=$(detect_source "$tool")
            [[ -z "$src" || "$src" == "unknown" ]] && continue
            display=$(source_display "$src")
            light=$(source_light "$src")
            color=$(source_color "$display")
            printf "[${C_CHECK}] ${light}%-20s${C_RESET} [${color}%s${C_RESET}] (dep)\n" "$tool" "$display"
            echo "TOOL=$tool" >> "$SAT_MANIFEST"
            echo "SOURCE_$tool=$src" >> "$SAT_MANIFEST"
            _master_add "$tool" "$src"
        fi
    done
    echo ""
fi

echo "type 'exit' to leave"
echo ""
RCFILE_MAIN

    # Launch shell - tmux for true isolation, fallback otherwise
    if command -v tmux &>/dev/null; then
        tmux new-session -s "sat-$$" "bash --rcfile $rcfile"
    else
        bash --rcfile "$rcfile"
    fi

    # Cleanup on exit
    shell_cleanup "$$" "$session_dir"
}
