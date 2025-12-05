#!/usr/bin/env bash
# sat install - install programs from various sources

install_from_release() {
    local repo_path="$1" repo_name="$2"
    local os arch base_url tmpdir

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

    wget -q -O "$tmpdir/$asset_name" "$base_url/$asset_name" || { rm -rf "$tmpdir"; return 1; }

    case "$asset_name" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmpdir/$asset_name" -C "$tmpdir"
            ;;
        *.zip)
            unzip -q "$tmpdir/$asset_name" -d "$tmpdir" 2>/dev/null
            ;;
        *)
            chmod +x "$tmpdir/$asset_name"
            mv "$tmpdir/$asset_name" "$HOME/.local/bin/$repo_name"
            rm -rf "$tmpdir"
            return 0
            ;;
    esac

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

    for arg in "$@"; do
        case "$arg" in
            --system|--sys) DEFAULT_SOURCE="system" ;;
            --rust|--rs)    DEFAULT_SOURCE="cargo" ;;
            --python|--py)  DEFAULT_SOURCE="uv" ;;
            --node|--js)    DEFAULT_SOURCE="npm" ;;
            --go)           DEFAULT_SOURCE="go" ;;
            --brew)         DEFAULT_SOURCE="brew" ;;
            --nix)          DEFAULT_SOURCE="nix" ;;
            --gh|--github)  DEFAULT_SOURCE="gh" ;;
            *)              SPECS+=("$arg") ;;
        esac
    done

    # Helper: add to system manifest (promotes from master if exists there)
    _track_install() {
        local tool="$1" src="$2"
        if master_has_tool "$tool"; then
            master_promote "$tool" "$src"
            printf "  ${C_DIM}(promoted from shell session)${C_RESET}\n"
        else
            manifest_add "$tool" "$src"
        fi
    }

    for SPEC in "${SPECS[@]}"; do
        parse_tool_spec "$SPEC"
        local PROGRAM="$_TOOL_NAME"
        local FORCE_SOURCE="${_TOOL_SOURCE:-$DEFAULT_SOURCE}"

        if [[ "$PROGRAM" == */* ]]; then
            local REPO_PATH="$PROGRAM"
            local REPO_NAME="${PROGRAM##*/}"

            # Try huber first (GitHub release manager)
            if command -v huber &>/dev/null; then
                source "$SAT_LIB/huber.sh"
                huber_cmd install "$REPO_PATH" &>/dev/null &
                spin_with_style "$REPO_NAME" $! "gh"
                if wait $!; then
                    _track_install "$REPO_NAME" "gh:$REPO_PATH"
                    status_ok "$REPO_NAME" "gh"
                    continue
                fi
            else
                printf "  ${C_DIM}(huber not found - install with: sat source huber)${C_RESET}\n"
            fi

            # Fall back to install.sh
            local INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/main/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                curl -sSL "$INSTALL_URL" | bash
                _track_install "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/master/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                curl -sSL "$INSTALL_URL" | bash
                _track_install "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            install_from_release "$REPO_PATH" "$REPO_NAME" &
            spin_with_style "$REPO_NAME" $! "repo"
            if wait $!; then
                _track_install "$REPO_NAME" "repo:$REPO_PATH"
                status_ok "$REPO_NAME" "repo"
                continue
            fi

            if command -v go &>/dev/null; then
                go install "github.com/$REPO_PATH@latest" &>/dev/null &
                spin_with_style "$REPO_NAME" $! "go"
                if wait $!; then
                    _track_install "$REPO_NAME" "go:github.com/$REPO_PATH"
                    status_ok "$REPO_NAME" "go"
                    continue
                fi
            fi

            status_fail "$REPO_NAME not found"
            continue
        fi

        if [[ -z "$FORCE_SOURCE" ]] && command -v "$PROGRAM" &>/dev/null; then
            local existing_src=$(detect_source "$PROGRAM")
            # If in master manifest, offer to promote
            if master_has_tool "$PROGRAM"; then
                local display=$(source_display "$existing_src")
                local color=$(source_color "$display")
                printf "%-30s [${color}%s${C_RESET}]\n" "$PROGRAM (shell session)" "$display"
                master_promote "$PROGRAM" "$existing_src"
                printf "  ${C_DIM}Promoted to system manifest${C_RESET}\n"
                continue
            fi
            local display=$(source_display "$existing_src")
            local color=$(source_color "$display")
            printf "%-30s [${color}%s${C_RESET}]\n" "$PROGRAM already installed" "$display"
            printf "  ${C_DIM}Use $PROGRAM:sys :brew :nix :rs :py :js :go to force${C_RESET}\n"
            continue
        fi

        if [[ -n "$FORCE_SOURCE" ]]; then
            # Special handling for gh - search GitHub API for repo
            if [[ "$FORCE_SOURCE" == "gh" ]]; then
                if ! command -v huber &>/dev/null; then
                    status_fail "$PROGRAM - huber not found (install with: sat source huber)"
                    continue
                fi
                source "$SAT_LIB/huber.sh"
                # Search GitHub API for top match
                local repo=$(curl -s "https://api.github.com/search/repositories?q=$PROGRAM&per_page=1" | jq -r '.items[0].full_name' 2>/dev/null)
                if [[ -z "$repo" || "$repo" == "null" ]]; then
                    status_fail "$PROGRAM not found on GitHub"
                    continue
                fi
                huber_cmd install "$repo" &>/dev/null &
                spin_with_style "$PROGRAM" $! "gh"
                if wait $!; then
                    _track_install "$PROGRAM" "gh:$repo"
                    status_ok "$PROGRAM" "gh"
                else
                    status_fail "$PROGRAM ($repo) install failed"
                fi
                continue
            fi

            try_source "$PROGRAM" "$FORCE_SOURCE" &
            spin_with_style "$PROGRAM" $! "$FORCE_SOURCE"
            if wait $!; then
                _track_install "$PROGRAM" "$FORCE_SOURCE"
                status_ok "$PROGRAM" "$FORCE_SOURCE"
            else
                status_fail "$PROGRAM not found in $(source_display "$FORCE_SOURCE")"
            fi
            continue
        fi

        if install_with_fallback "$PROGRAM"; then
            _track_install "$PROGRAM" "$_INSTALL_SOURCE"
            status_ok "$PROGRAM" "$_INSTALL_SOURCE"
        else
            status_fail "$PROGRAM not found"
        fi
    done
}
