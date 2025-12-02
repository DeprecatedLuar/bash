#!/usr/bin/env bash
# sat common - shared functions

SAT_BASE="https://raw.githubusercontent.com/$GITHUB_USER/the-satellite/main"
SAT_LOCAL="$PROJECTS/cli/the-satellite"
SAT_DATA="$HOME/.local/share/sat"
SAT_MANIFEST="$SAT_DATA/manifest"

# Ensure data dir exists
mkdir -p "$SAT_DATA"
touch "$SAT_MANIFEST"

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
        npm)     npm uninstall -g "$pkg" ;;
        wrapper) rm -f "$HOME/.local/bin/$pkg" ;;
        repo)    rm -f "$HOME/.local/bin/$pkg" ;;
        repo:*)  rm -f "$HOME/.local/bin/$pkg" ;;
        *)       return 1 ;;
    esac
}
