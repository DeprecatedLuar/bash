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
C_NIX=$'\033[0;95m'       # Bright magenta - Nix
C_MANUAL=$'\033[38;2;180;140;100m'  # Warm brown - Manual installs

# Desaturated colors (for item names - pastel tints, closer to white)
C_RUST_L=$'\033[38;2;220;160;160m'    # Soft pink-red
C_NODE_L=$'\033[38;2;160;210;160m'    # Soft mint
C_PYTHON_L=$'\033[38;2;220;210;160m'  # Soft cream
C_SYSTEM_L=$'\033[38;2;160;180;220m'  # Soft sky blue
C_REPO_L=$'\033[38;2;180;180;180m'    # Soft gray
C_GO_L=$'\033[38;2;160;210;210m'      # Soft teal
C_BREW_L=$'\033[38;2;230;175;130m'    # Soft amber
C_NIX_L=$'\033[38;2;200;170;220m'     # Soft lavender
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

# Install fallback order (ecosystem isolation first, system last)
INSTALL_ORDER=(cargo uv npm system repo wrapper)

SAT_BASE="https://raw.githubusercontent.com/$GITHUB_USER/the-satellite/main"
SAT_LOCAL="$PROJECTS/cli/the-satellite"
SAT_DATA="$HOME/.local/share/sat"
SAT_MANIFEST="$SAT_DATA/manifest"
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

# Animated status output
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

status() { printf "\r%-40s\n" "$1"; }

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
        */.local/share/uv/tools/*|*/.local/bin/*) echo "uv" ;;
        */linuxbrew/*|*/homebrew/*)              echo "brew" ;;
        /nix/store/*|*/.nix-profile/*)           echo "nix" ;;
        /usr/bin/*|/bin/*|/usr/local/bin/*|/usr/games/*) echo "system" ;;
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
    # Clear bash hash cache for this command
    hash -d "$pkg" 2>/dev/null
}

