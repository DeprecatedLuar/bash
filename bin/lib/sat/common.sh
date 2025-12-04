#!/usr/bin/env bash
# sat common - shared functions

# Colors by source (headers)
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_RUST=$'\033[0;91m'      # Bright red - Rust/cargo
C_NODE=$'\033[0;92m'      # Bright green - Node/npm
C_PYTHON=$'\033[0;94m'    # Blue - Python/uv
C_SYSTEM=$'\033[0;97m'    # Bright white - System packages
C_REPO=$'\033[38;2;140;140;140m'  # Medium gray - GitHub repos
C_WRAPPER=$'\033[0;36m'   # Cyan - Sat wrappers
C_GO=$'\033[0;96m'        # Bright Cyan - Go
C_BREW=$'\033[0;93m'      # Bright yellow - Homebrew
C_NIX=$'\033[38;2;82;119;195m'    # Dark blue #5277C3 - Nix
C_MANUAL=$'\033[38;2;180;140;100m'  # Warm brown - Manual installs

# Desaturated colors (for item names - pastel tints, closer to white)
C_RUST_L=$'\033[38;2;220;160;160m'    # Soft pink-red
C_NODE_L=$'\033[38;2;160;210;160m'    # Soft mint
C_PYTHON_L=$'\033[38;2;220;210;160m'  # Soft cream
C_SYSTEM_L=$'\033[38;2;160;180;220m'  # Soft sky blue
C_REPO_L=$'\033[38;2;180;180;180m'    # Soft gray
C_GO_L=$'\033[38;2;160;210;210m'      # Soft teal
C_BREW_L=$'\033[38;2;230;175;130m'    # Soft amber
C_NIX_L=$'\033[38;2;126;186;228m'     # Light blue #7EBAE4
C_MANUAL_L=$'\033[38;2;210;180;150m'  # Soft tan

# Map source to color
source_color() {
    case "$1" in
        cargo|rust)                  printf '%s' "$C_RUST" ;;
        npm|node)                    printf '%s' "$C_NODE" ;;
        uv|pip|python)               printf '%s' "$C_PYTHON" ;;
        apt|apk|pacman|dnf|pkg|system) printf '%s' "$C_SYSTEM" ;;
        repo|repo:*)                 printf '%s' "$C_REPO" ;;
        wrapper)                     printf '%s' "$C_WRAPPER" ;;
        go|go:*)                     printf '%s' "$C_GO" ;;
        brew)                        printf '%s' "$C_BREW" ;;
        nix)                         printf '%s' "$C_NIX" ;;
        manual)                      printf '%s' "$C_MANUAL" ;;
        unknown)                     printf '%s' "$C_DIM" ;;
        *)                           printf '%s' "$C_RESET" ;;
    esac
}

# Install fallback order for permanent installs (system first for stability)
INSTALL_ORDER=(system brew nix cargo uv npm repo wrapper)

# Install order for sat shell (isolated/user-space first, system before npm)
SHELL_INSTALL_ORDER=(brew nix cargo uv system npm repo wrapper)

SAT_BASE="https://raw.githubusercontent.com/DeprecatedLuar/the-satellite/main"
SAT_LOCAL="$PROJECTS/cli/the-satellite"
SAT_DATA="$HOME/.local/share/sat"
SAT_MANIFEST="${SAT_MANIFEST:-$SAT_DATA/manifest}"
SAT_SHELL_MASTER="$SAT_DATA/shell-manifest"
SAT_RUN_DIR="/tmp/sat-shell"

# Ensure data dir exists
mkdir -p "$SAT_DATA"
touch "$SAT_MANIFEST"
touch "$SAT_SHELL_MASTER"

# Source OS detection (local or remote)
if [[ -f "$SAT_LOCAL/internal/os_detection.sh" ]]; then
    source "$SAT_LOCAL/internal/os_detection.sh"
else
    source <(curl -sSL "$SAT_BASE/internal/os_detection.sh")
fi

# Manifest helpers
manifest_add() { echo "$1=$2" >> "$SAT_MANIFEST"; }
manifest_get() { grep "^$1=" "$SAT_MANIFEST" 2>/dev/null | cut -d= -f2; }
manifest_remove() { sed -i "/^$1=/d" "$SAT_MANIFEST"; }

# Animated status output (legacy)
spin() {
    local msg="$1" pid="$2"
    local dots=""
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s%-3s" "$msg" "$dots"
        dots="${dots}."
        [[ ${#dots} -gt 3 ]] && dots=""
        sleep 0.2
    done
}

# Styled spinner: [/] package [source] with colored frames
spin_with_style() {
    local program="$1" pid="$2" source="$3"
    local frames=('|' '/' '-' $'\\')
    local frame_colors=("$C_RUST" "$C_NODE" "$C_PYTHON" "$C_BREW")
    local i=0
    local pkg_color=$(source_light "$source")
    local src_display=$(source_display "$source")
    local src_color=$(source_color "$src_display")

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r[${frame_colors[i]}%s${C_RESET}] ${pkg_color}%s${C_RESET} [${src_color}%s${C_RESET}]" \
            "${frames[i]}" "$program" "$src_display"
        i=$(( (i + 1) % 4 ))
        sleep 0.15
    done
    printf "\r%-50s\r" ""
}

# Spinner without source tag (for searching/probing)
spin_probe() {
    local program="$1" pid="$2"
    local frames=('|' '/' '-' $'\\')
    local frame_colors=("$C_RUST" "$C_NODE" "$C_PYTHON" "$C_BREW")
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r[${frame_colors[i]}%s${C_RESET}] ${C_DIM}%s${C_RESET}" \
            "${frames[i]}" "$program"
        i=$(( (i + 1) % 4 ))
        sleep 0.15
    done
    printf "\r%-50s\r" ""
}

# Checkmark and X for completion status
C_CHECK=$'\033[0;92m✓\033[0m'  # Green checkmark
C_CROSS=$'\033[0;91m✗\033[0m'  # Red X

status() { printf "\r%-40s\n" "$1"; }

# Status with checkmark/cross and source tag
status_ok() {
    local msg="$1" src="$2"
    local display=$(source_display "$src")
    local color=$(source_color "$display")
    printf "\r[${C_CHECK}] %-25s [${color}%s${C_RESET}]\n" "$msg" "$display"
}

status_fail() {
    local msg="$1"
    printf "\r[${C_CROSS}] %s\n" "$msg"
}

# Map internal source to display name
source_display() {
    case "$1" in
        npm)    echo "node" ;;
        uv)     echo "python" ;;
        cargo)  echo "rust" ;;
        *)      echo "$1" ;;
    esac
}

# Get pastel color for source (item names)
source_light() {
    case "$1" in
        npm|node)                      printf '%s' "$C_NODE_L" ;;
        uv|pip|python)                 printf '%s' "$C_PYTHON_L" ;;
        cargo|rust)                    printf '%s' "$C_RUST_L" ;;
        apt|apk|pacman|dnf|pkg|system) printf '%s' "$C_SYSTEM_L" ;;
        wrapper|repo|repo:*)           printf '%s' "$C_REPO_L" ;;
        go|go:*)                       printf '%s' "$C_GO_L" ;;
        brew)                          printf '%s' "$C_BREW_L" ;;
        nix)                           printf '%s' "$C_NIX_L" ;;
        manual)                        printf '%s' "$C_MANUAL_L" ;;
        unknown)                       printf '%s' "$C_DIM" ;;
        *)                             printf '%s' "$C_RESET" ;;
    esac
}

# Colored status with source tag
status_src() {
    local msg="$1" src="$2"
    local display=$(source_display "$src")
    local color=$(source_color "$display")
    printf "\r%-30s [${color}%s${C_RESET}]\n" "$msg" "$display"
}

# Parse tool:source syntax (e.g., "ranger:py" -> tool=ranger, source=uv)
# Sets globals: _TOOL_NAME, _TOOL_SOURCE (empty if no source specified)
parse_tool_spec() {
    local spec="$1"
    if [[ "$spec" == *:* ]]; then
        _TOOL_NAME="${spec%%:*}"
        local src="${spec##*:}"
        case "$src" in
            py|python)   _TOOL_SOURCE="uv" ;;
            rs|rust)     _TOOL_SOURCE="cargo" ;;
            js|node)     _TOOL_SOURCE="npm" ;;
            sys|system)  _TOOL_SOURCE="system" ;;
            go)          _TOOL_SOURCE="go" ;;
            brew)        _TOOL_SOURCE="brew" ;;
            nix)         _TOOL_SOURCE="nix" ;;
            *)           _TOOL_SOURCE="$src" ;;
        esac
    else
        _TOOL_NAME="$spec"
        _TOOL_SOURCE=""
    fi
}

# Detect source from binary location (fallback when not in manifests)
detect_source() {
    local tool="$1"
    local bin=$(command -v "$tool" 2>/dev/null)
    [[ -z "$bin" ]] && return

    # Resolve symlinks to find actual location
    bin=$(readlink -f "$bin" 2>/dev/null || echo "$bin")

    case "$bin" in
        */.cargo/bin/*|*/dev-tools/cargo/bin/*)  echo "cargo" ;;
        */dev-tools/npm/*|*/.npm-global/*)       echo "npm" ;;
        */dev-tools/go/bin/*|*/go/bin/*)         echo "go" ;;
        */.local/share/uv/tools/*) echo "uv" ;;
        */linuxbrew/*|*/homebrew/*)              echo "brew" ;;
        /nix/store/*|*/.nix-profile/*)           echo "nix" ;;
        /usr/bin/*|/bin/*|/usr/local/bin/*|/usr/games/*|/sbin/*|/usr/sbin/*) echo "system" ;;
        */.local/opt/*)                          echo "manual" ;;
        *)                                       echo "unknown" ;;
    esac
}

# Layered source lookup: session manifest -> system manifest -> binary detection
resolve_source() {
    local tool="$1" session_manifest="$2"
    local src=""

    # Layer 1: Session manifest (tools installed this session)
    [[ -n "$session_manifest" && -f "$session_manifest" ]] && \
        src=$(grep "^SOURCE_$tool=" "$session_manifest" 2>/dev/null | cut -d= -f2)

    # Layer 2: System manifest (permanently installed via sat)
    [[ -z "$src" ]] && src=$(manifest_get "$tool")

    # Layer 3: Detect from binary location
    [[ -z "$src" ]] && src=$(detect_source "$tool")

    # Layer 4: Unknown (not "system" - that would be misleading)
    [[ -z "$src" ]] && src="unknown"

    echo "$src"
}

# Find ALL installations of a tool across ecosystems
# Returns: source:path pairs, one per line (active source first)
resolve_all_sources() {
    local tool="$1"
    local results=()
    local seen_reals=()
    local active_bin=$(command -v "$tool" 2>/dev/null)
    local active_real=""
    [[ -n "$active_bin" ]] && active_real=$(readlink -f "$active_bin" 2>/dev/null || echo "$active_bin")

    # Define search paths for each ecosystem
    declare -A eco_paths=(
        [cargo]="$HOME/.cargo/bin $HOME/.config/bash/dev-tools/cargo/bin"
        [npm]="$HOME/.config/bash/dev-tools/npm/bin $HOME/.npm-global/bin"
        [uv]="$HOME/.local/share/uv/tools/*/bin"
        [go]="$HOME/go/bin $HOME/.config/bash/dev-tools/go/bin"
        [brew]="/home/linuxbrew/.linuxbrew/bin"
        [nix]="$HOME/.nix-profile/bin"
        [system]="/usr/bin /usr/local/bin /usr/games"
    )

    # Check each ecosystem
    for src in "${!eco_paths[@]}"; do
        for dir in ${eco_paths[$src]}; do
            # Handle glob patterns (for uv)
            for bin in $dir/$tool; do
                if [[ -x "$bin" ]]; then
                    local real=$(readlink -f "$bin" 2>/dev/null || echo "$bin")
                    # Skip if we've already seen this real path
                    [[ " ${seen_reals[*]} " =~ " $real " ]] && continue
                    seen_reals+=("$real")

                    # Check if this is the active one
                    if [[ -n "$active_real" && "$real" == "$active_real" ]]; then
                        results=("$src:$bin:active" "${results[@]}")
                    else
                        results+=("$src:$bin:shadowed")
                    fi
                    break  # Found in this ecosystem, move to next
                fi
            done
        done
    done

    # Output results
    printf '%s\n' "${results[@]}"
}

# Detect package manager based on distro family
get_pkg_manager() {
    local distro family
    distro=$(detect_distro "$(detect_os)")
    family=$(detect_distro_family "$distro")

    case "$distro" in
        termux) echo "pkg" ;;
        *)
            case "$family" in
                debian) echo "apt" ;;
                alpine) echo "apk" ;;
                arch)   echo "pacman" ;;
                rhel)   echo "dnf" ;;
                *)      echo "" ;;
            esac
            ;;
    esac
}

# Check if package exists in native repo
pkg_exists() {
    local pkg="$1" mgr="$2"
    case "$mgr" in
        apt)    apt-cache show "$pkg" &>/dev/null ;;
        apk)    apk info -e "$pkg" &>/dev/null ;;
        pacman) pacman -Si "$pkg" &>/dev/null ;;
        dnf)    dnf info "$pkg" &>/dev/null ;;
        pkg)    pkg search -e "^${pkg}$" &>/dev/null ;;
        *)      return 1 ;;
    esac
}

# Install package via native package manager
pkg_install() {
    local pkg="$1" mgr="$2"
    case "$mgr" in
        apt)    sudo apt install -y "$pkg" ;;
        apk)    sudo apk add "$pkg" ;;
        pacman) sudo pacman -S --noconfirm "$pkg" ;;
        dnf)    sudo dnf install -y "$pkg" ;;
        pkg)    pkg install -y "$pkg" ;;
        *)      return 1 ;;
    esac
}

# Remove package via source
pkg_remove() {
    local pkg="$1" source="$2"
    case "$source" in
        apt)     sudo apt remove --purge -y "$pkg" && sudo apt autoremove -y ;;
        apk)     sudo apk del "$pkg" ;;
        pacman)  sudo pacman -Rs --noconfirm "$pkg" ;;
        dnf)     sudo dnf remove -y "$pkg" ;;
        pkg)     pkg uninstall -y "$pkg" ;;
        uv)      uv tool uninstall "$pkg" ;;
        cargo)
            # Binary name may differ from crate name - look it up
            crate=$(cargo install --list 2>/dev/null | grep -B1 "^    $pkg\$" | head -1 | cut -d' ' -f1)
            cargo uninstall "${crate:-$pkg}"
            ;;
        npm)     npm uninstall -g "$pkg" ;;
        go:*)    rm -f "$GOPATH/bin/$pkg" "$HOME/go/bin/$pkg" 2>/dev/null ;;
        brew)    brew uninstall "$pkg" ;;
        nix)     nix-env --uninstall "$pkg" 2>/dev/null || nix profile remove "$pkg" ;;
        wrapper) rm -f "$HOME/.local/bin/$pkg" ;;
        repo)    rm -f "$HOME/.local/bin/$pkg" ;;
        repo:*)  rm -f "$HOME/.local/bin/$pkg" ;;
        system)  # Generic system - detect package manager
            local mgr=$(get_pkg_manager)
            [[ -z "$mgr" ]] && return 1
            pkg_remove "$pkg" "$mgr"
            return $?
            ;;
        *)       return 1 ;;
    esac
}

# === Core Install Functions ===

# Try installing from a specific source (runs synchronously)
# Returns 0 on success, 1 on failure
try_source() {
    local tool="$1" source="$2"

    case "$source" in
        cargo)
            command -v cargo &>/dev/null || return 1
            cargo install "$tool" &>/dev/null
            ;;
        uv)
            command -v uv &>/dev/null || return 1
            uv tool install "$tool" &>/dev/null
            ;;
        npm)
            command -v npm &>/dev/null || return 1
            npm show "$tool" >/dev/null 2>&1 || return 1
            npm install -g "$tool" &>/dev/null || return 1
            command -v "$tool" &>/dev/null  # Verify binary exists
            ;;
        go)
            command -v go &>/dev/null || return 1
            local go_pkg="$tool"
            [[ "$go_pkg" != *"."* ]] && go_pkg="github.com/$tool"
            go install "${go_pkg}@latest" &>/dev/null
            ;;
        brew)
            command -v brew &>/dev/null || return 1
            brew info "$tool" &>/dev/null 2>&1 || return 1
            brew install "$tool" &>/dev/null
            ;;
        nix)
            command -v nix-env &>/dev/null || return 1
            nix-env -iA "nixpkgs.$tool" &>/dev/null
            ;;
        system)
            local mgr=$(get_pkg_manager)
            [[ -z "$mgr" ]] && return 1
            pkg_exists "$tool" "$mgr" || return 1
            pkg_install "$tool" "$mgr" &>/dev/null
            ;;
        repo)
            # Check user's GitHub repo for install.sh
            local url="https://raw.githubusercontent.com/$GITHUB_USER/$tool/main/install.sh"
            curl -sSL --fail --head "$url" >/dev/null 2>&1 || {
                url="https://raw.githubusercontent.com/$GITHUB_USER/$tool/master/install.sh"
                curl -sSL --fail --head "$url" >/dev/null 2>&1 || return 1
            }
            curl -sSL "$url" | bash &>/dev/null
            ;;
        wrapper)
            curl -sSL --fail --head "$SAT_BASE/cargo-bay/programs/${tool}.sh" >/dev/null 2>&1 || return 1
            source <(curl -sSL "$SAT_BASE/internal/fetcher.sh")
            sat_init && sat_run "$tool" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Install tool with fallback chain, using spinner
# Sets global: _INSTALL_SOURCE (source that succeeded)
# Returns 0 on success, 1 if all sources fail
install_with_fallback() {
    local tool="$1"
    _INSTALL_SOURCE=""

    for source in "${INSTALL_ORDER[@]}"; do
        try_source "$tool" "$source" &
        spin_probe "$tool" $!
        if wait $!; then
            _INSTALL_SOURCE="$source"
            return 0
        fi
    done

    return 1
}

# =============================================================================
# SNAPSHOT-BASED CONFIG CLEANUP (for sat shell)
# =============================================================================

# Session storage location (persistent, survives crashes)
SAT_SESSIONS_DIR="$SAT_DATA/sessions"

# Take snapshot of config directories and dotfiles
take_snapshot() {
    local snapshot_file="$1"
    {
        # XDG Base Directories
        [[ -d "$HOME/.config" ]] && find "$HOME/.config" -maxdepth 1 -type d -printf "%f\n"
        [[ -d "$HOME/.local/share" ]] && find "$HOME/.local/share" -maxdepth 1 -type d -printf "%f\n"
        [[ -d "$HOME/.local/state" ]] && find "$HOME/.local/state" -maxdepth 1 -type d -printf "%f\n"
        [[ -d "$HOME/.cache" ]] && find "$HOME/.cache" -maxdepth 1 -type d -printf "%f\n"

        # Root home dotfiles (hidden files/dirs starting with .)
        find "$HOME" -maxdepth 1 -name ".*" \( -type f -o -type d \) -printf "%f\n"
    } 2>/dev/null | grep -v '^\.$' | sort -u > "$snapshot_file"
}

# Word boundary matching - check if tool name appears as complete word in dir name
# Example: "saul" matches "better-curl-saul" but not "saulconfig"
# Separators: dash (-), underscore (_), start/end of string
matches_tool_name() {
    local dir_name="$1"
    local tool="$2"

    # Skip very short names (too risky - "go", "fd", etc)
    [[ ${#tool} -lt 3 ]] && return 1

    # Case-insensitive comparison
    local dir_lower="${dir_name,,}"
    local tool_lower="${tool,,}"

    # Check if tool appears as a complete word
    # Regex: (start OR separator) + tool + (separator OR end)
    if [[ "$dir_lower" =~ (^|[-_])${tool_lower}([-_]|$) ]]; then
        return 0
    fi

    return 1
}

# Clean up configs created during session
cleanup_session_configs() {
    local snapshot_before="$1"
    local snapshot_after="$2"
    local manifest="$3"

    # Take snapshot after session
    take_snapshot "$snapshot_after"

    # Get list of installed tools from manifest
    local installed_tools=()
    while IFS='=' read -r key value; do
        [[ "$key" == "TOOL" ]] && installed_tools+=("$value")
    done < "$manifest"

    [[ ${#installed_tools[@]} -eq 0 ]] && return

    # Find new items (created during session)
    local new_items=$(comm -13 "$snapshot_before" "$snapshot_after")

    # Match and remove items that match installed tools
    while IFS= read -r item_name; do
        [[ -z "$item_name" ]] && continue

        for tool in "${installed_tools[@]}"; do
            if matches_tool_name "$item_name" "$tool"; then
                # XDG locations
                [[ -d "$HOME/.config/$item_name" ]] && rm -rf "$HOME/.config/$item_name" && \
                    printf "  ${C_DIM}Removed config: ~/.config/$item_name${C_RESET}\n"
                [[ -d "$HOME/.local/share/$item_name" ]] && rm -rf "$HOME/.local/share/$item_name" && \
                    printf "  ${C_DIM}Removed data: ~/.local/share/$item_name${C_RESET}\n"
                [[ -d "$HOME/.local/state/$item_name" ]] && rm -rf "$HOME/.local/state/$item_name" && \
                    printf "  ${C_DIM}Removed state: ~/.local/state/$item_name${C_RESET}\n"
                [[ -d "$HOME/.cache/$item_name" ]] && rm -rf "$HOME/.cache/$item_name" && \
                    printf "  ${C_DIM}Removed cache: ~/.cache/$item_name${C_RESET}\n"

                # Root dotfiles (files or directories)
                [[ -e "$HOME/$item_name" ]] && rm -rf "$HOME/$item_name" && \
                    printf "  ${C_DIM}Removed dotfile: ~/$item_name${C_RESET}\n"

                break
            fi
        done
    done <<< "$new_items"
}

# Clean up sessions from dead processes (crash recovery)
cleanup_orphaned_sessions() {
    [[ ! -d "$SAT_SESSIONS_DIR" ]] && return

    for session_dir in "$SAT_SESSIONS_DIR"/*/; do
        [[ ! -d "$session_dir" ]] && continue

        local pid=$(basename "$session_dir")

        # Check if process still alive
        if ! kill -0 "$pid" 2>/dev/null; then
            printf "${C_DIM}Cleaning orphaned session: $pid${C_RESET}\n"

            # If snapshots exist, clean up configs
            if [[ -f "$session_dir/manifest" && -f "$session_dir/snapshot-before.txt" ]]; then
                local snapshot_after="$session_dir/snapshot-after.txt"
                take_snapshot "$snapshot_after"
                cleanup_session_configs \
                    "$session_dir/snapshot-before.txt" \
                    "$snapshot_after" \
                    "$session_dir/manifest"
            fi

            # Remove packages
            if [[ -f "$session_dir/manifest" ]]; then
                while IFS='=' read -r key value; do
                    if [[ "$key" == "TOOL" ]]; then
                        local src=$(grep "^SOURCE_$value=" "$session_dir/manifest" | cut -d= -f2)
                        [[ -n "$src" ]] && pkg_remove "$value" "$src" >/dev/null 2>&1
                    fi
                done < "$session_dir/manifest"
            fi

            rm -rf "$session_dir"
        fi
    done
}

# =============================================================================
# DEPENDENCIES
# =============================================================================

# Core dependencies (required for sat to function)
SAT_DEPS=(jq curl)

# Ensure all dependencies are installed
ensure_deps() {
    local missing=()
    for dep in "${SAT_DEPS[@]}"; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done

    [[ ${#missing[@]} -eq 0 ]] && return 0

    local mgr=$(get_pkg_manager)
    if [[ -z "$mgr" ]]; then
        printf "${C_DIM}sat: missing deps (%s) - install manually${C_RESET}\n" "${missing[*]}" >&2
        return 1
    fi

    printf "${C_DIM}sat: installing %s...${C_RESET}\n" "${missing[*]}" >&2
    for dep in "${missing[@]}"; do
        pkg_install "$dep" "$mgr" || {
            printf "${C_DIM}sat: failed to install %s${C_RESET}\n" "$dep" >&2
            return 1
        }
    done
}

# Run on source
ensure_deps

