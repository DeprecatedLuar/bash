#!/usr/bin/env bash
# sat install - install programs from various sources

# Download and install binary from GitHub releases
# Usage: install_from_release <user/repo> <repo_name>
install_from_release() {
    local repo_path="$1" repo_name="$2"
    local os arch base_url tmpdir

    # Detect OS/arch
    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        *)       return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="arm" ;;
        *)       return 1 ;;
    esac

    base_url="https://github.com/$repo_path/releases/latest/download"
    tmpdir=$(mktemp -d)
    mkdir -p "$HOME/.local/bin"

    # Try common naming patterns (first hit wins)
    local patterns=(
        "$repo_name-$os-$arch"
        "$repo_name-${os}-${arch}.tar.gz"
        "$repo_name-${os}-${arch}.zip"
        "${repo_name}_${os}_${arch}"
        "${repo_name}_${os}_${arch}.tar.gz"
        "$repo_name-$os-x86_64"
        "${repo_name}-${os}-x86_64.tar.gz"
    )

    local asset_name=""
    for pattern in "${patterns[@]}"; do
        if wget -q --spider "$base_url/$pattern" 2>/dev/null; then
            asset_name="$pattern"
            break
        fi
    done

    [[ -z "$asset_name" ]] && { rm -rf "$tmpdir"; return 1; }

    # Download
    wget -q -O "$tmpdir/$asset_name" "$base_url/$asset_name" || { rm -rf "$tmpdir"; return 1; }

    # Extract or install directly
    case "$asset_name" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmpdir/$asset_name" -C "$tmpdir"
            ;;
        *.zip)
            unzip -q "$tmpdir/$asset_name" -d "$tmpdir" 2>/dev/null
            ;;
        *)
            # Raw binary
            chmod +x "$tmpdir/$asset_name"
            mv "$tmpdir/$asset_name" "$HOME/.local/bin/$repo_name"
            rm -rf "$tmpdir"
            return 0
            ;;
    esac

    # Find the binary in extracted files
    local binary
    binary=$(find "$tmpdir" -type f -name "$repo_name" 2>/dev/null | head -1)
    [[ -z "$binary" ]] && binary=$(find "$tmpdir" -type f -executable ! -name "*.sh" 2>/dev/null | head -1)

    if [[ -n "$binary" ]]; then
        chmod +x "$binary"
        mv "$binary" "$HOME/.local/bin/$repo_name"
        rm -rf "$tmpdir"
        return 0
    fi

    rm -rf "$tmpdir"
    return 1
}

sat_install() {
    local DEFAULT_SOURCE=""
    local -a SPECS=()

    # Parse args: flags set default source, others are tool specs
    for arg in "$@"; do
        case "$arg" in
            --system|--sys) DEFAULT_SOURCE="system" ;;
            --rust|--rs)    DEFAULT_SOURCE="cargo" ;;
            --python|--py)  DEFAULT_SOURCE="uv" ;;
            --node|--js)    DEFAULT_SOURCE="npm" ;;
            --go)           DEFAULT_SOURCE="go" ;;
            --brew)         DEFAULT_SOURCE="brew" ;;
            --nix)          DEFAULT_SOURCE="nix" ;;
            *)              SPECS+=("$arg") ;;
        esac
    done

    for SPEC in "${SPECS[@]}"; do
        # Parse tool:source syntax
        parse_tool_spec "$SPEC"
        local PROGRAM="$_TOOL_NAME"
        local FORCE_SOURCE="${_TOOL_SOURCE:-$DEFAULT_SOURCE}"
        # Handle GitHub repo format (user/repo)
        if [[ "$PROGRAM" == */* ]]; then
            local REPO_PATH="$PROGRAM"
            local REPO_NAME="${PROGRAM##*/}"

            # Try install.sh (main branch)
            local INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/main/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                curl -sSL "$INSTALL_URL" | bash
                manifest_add "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            # Try master branch
            INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/master/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                curl -sSL "$INSTALL_URL" | bash
                manifest_add "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            # Try GitHub releases (download binary)
            install_from_release "$REPO_PATH" "$REPO_NAME" &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                manifest_add "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            # Try go install
            if command -v go &>/dev/null; then
                go install "github.com/$REPO_PATH@latest" &>/dev/null &
                spin_with_style "$REPO_NAME" $! "go"
                if wait $!; then
                    manifest_add "$REPO_NAME" "go:github.com/$REPO_PATH"
                    status_ok "$REPO_NAME" "go"
                    continue
                fi
            fi

            status_fail "$REPO_NAME not found"
            continue
        fi

        # Check if already installed (skip if forcing)
        if [[ -z "$FORCE_SOURCE" ]] && command -v "$PROGRAM" &>/dev/null; then
            local existing_src=$(detect_source "$PROGRAM")
            local display=$(source_display "$existing_src")
            local color=$(source_color "$display")
            printf "%-30s [${color}%s${C_RESET}]\n" "$PROGRAM already installed" "$display"
            printf "  ${C_DIM}Use $PROGRAM:sys :brew :nix :rs :py :js :go to force${C_RESET}\n"
            continue
        fi

        # Forced source install
        if [[ -n "$FORCE_SOURCE" ]]; then
            try_source "$PROGRAM" "$FORCE_SOURCE" &
            spin_with_style "$PROGRAM" $! "$FORCE_SOURCE"
            if wait $!; then
                manifest_add "$PROGRAM" "$FORCE_SOURCE"
                status_ok "$PROGRAM" "$FORCE_SOURCE"
            else
                status_fail "$PROGRAM not found in $(source_display "$FORCE_SOURCE")"
            fi
            continue
        fi

        # Fallback chain
        if install_with_fallback "$PROGRAM"; then
            manifest_add "$PROGRAM" "$_INSTALL_SOURCE"
            status_ok "$PROGRAM" "$_INSTALL_SOURCE"
        else
            status_fail "$PROGRAM not found"
        fi
    done
}
