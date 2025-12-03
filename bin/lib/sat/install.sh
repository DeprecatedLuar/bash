#!/usr/bin/env bash
# sat install - install programs from various sources

sat_install() {
    local PKG_MGR=$(get_pkg_manager)
    local FORCE_SOURCE=""
    local PROGRAMS=()

    # Parse flags
    for arg in "$@"; do
        case "$arg" in
            --system) FORCE_SOURCE="system" ;;
            --rust)   FORCE_SOURCE="cargo" ;;
            --python) FORCE_SOURCE="uv" ;;
            --node)   FORCE_SOURCE="npm" ;;
            --go)     FORCE_SOURCE="go" ;;
            *)        PROGRAMS+=("$arg") ;;
        esac
    done

    for PROGRAM in "${PROGRAMS[@]}"; do
        # Handle GitHub repo format (user/repo)
        if [[ "$PROGRAM" == */* ]]; then
            local REPO_PATH="$PROGRAM"
            local REPO_NAME="${PROGRAM##*/}"

            printf "Installing %s" "$REPO_NAME"

            # Try install.sh first
            local INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/main/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin "Installing $REPO_NAME" $!
            if wait $!; then
                printf "\r"
                curl -sSL "$INSTALL_URL" | bash
                manifest_add "$REPO_NAME" "repo:$REPO_PATH"
                status_src "$REPO_NAME installed" "repo"
                continue
            fi

            # Try master branch
            INSTALL_URL="https://raw.githubusercontent.com/$REPO_PATH/master/install.sh"
            curl -sSL --fail --head "$INSTALL_URL" >/dev/null 2>&1 &
            spin "Installing $REPO_NAME" $!
            if wait $!; then
                printf "\r"
                curl -sSL "$INSTALL_URL" | bash
                manifest_add "$REPO_NAME" "repo:$REPO_PATH"
                status_src "$REPO_NAME installed" "repo"
                continue
            fi

            status "$REPO_NAME install.sh not found"
            continue
        fi

        # 0. Check if already installed (skip if forcing)
        if [[ -z "$FORCE_SOURCE" ]] && command -v "$PROGRAM" &>/dev/null; then
            status "$PROGRAM already installed"
            continue
        fi

        printf "Installing %s" "$PROGRAM"

        # Forced source install
        if [[ -n "$FORCE_SOURCE" ]]; then
            case "$FORCE_SOURCE" in
                system)
                    if [[ -n "$PKG_MGR" ]] && pkg_exists "$PROGRAM" "$PKG_MGR"; then
                        pkg_install "$PROGRAM" "$PKG_MGR" && manifest_add "$PROGRAM" "$PKG_MGR"
                        status_src "$PROGRAM installed" "$PKG_MGR"
                    else
                        status "$PROGRAM not found in $PKG_MGR"
                    fi
                    ;;
                cargo)
                    cargo install "$PROGRAM" &>/dev/null &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        manifest_add "$PROGRAM" "cargo"
                        status_src "$PROGRAM installed" "cargo"
                    else
                        status "$PROGRAM not found in cargo"
                    fi
                    ;;
                uv)
                    uv tool install "$PROGRAM" &>/dev/null &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        manifest_add "$PROGRAM" "uv"
                        status_src "$PROGRAM installed" "uv"
                    else
                        status "$PROGRAM not found in uv"
                    fi
                    ;;
                npm)
                    npm install -g "$PROGRAM" &>/dev/null &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        manifest_add "$PROGRAM" "npm"
                        status_src "$PROGRAM installed" "npm"
                    else
                        status "$PROGRAM not found in npm"
                    fi
                    ;;
                go)
                    # Go requires full module path (github.com/user/repo or user/repo)
                    local GO_PKG="$PROGRAM"
                    [[ "$GO_PKG" != *"."* ]] && GO_PKG="github.com/$PROGRAM"
                    go install "${GO_PKG}@latest" &>/dev/null &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        manifest_add "${PROGRAM##*/}" "go:$GO_PKG"
                        status_src "${PROGRAM##*/} installed" "go"
                    else
                        status "$PROGRAM not found in go"
                    fi
                    ;;
            esac
            continue
        fi

        # === Fallback chain: follows INSTALL_ORDER from common.sh ===
        local installed=false

        for source in "${INSTALL_ORDER[@]}"; do
            $installed && break

            case "$source" in
                cargo)
                    if command -v cargo &>/dev/null; then
                        cargo install "$PROGRAM" &>/dev/null &
                        spin "Installing $PROGRAM" $!
                        if wait $!; then
                            manifest_add "$PROGRAM" "cargo"
                            status_src "$PROGRAM installed" "cargo"
                            installed=true
                        fi
                    fi
                    ;;
                uv)
                    if command -v uv &>/dev/null; then
                        uv tool install "$PROGRAM" &>/dev/null &
                        spin "Installing $PROGRAM" $!
                        if wait $!; then
                            manifest_add "$PROGRAM" "uv"
                            status_src "$PROGRAM installed" "uv"
                            installed=true
                        fi
                    fi
                    ;;
                npm)
                    if command -v npm &>/dev/null && npm show "$PROGRAM" >/dev/null 2>&1; then
                        npm install -g "$PROGRAM" &>/dev/null &
                        spin "Installing $PROGRAM" $!
                        if wait $!; then
                            manifest_add "$PROGRAM" "npm"
                            status_src "$PROGRAM installed" "npm"
                            installed=true
                        fi
                    fi
                    ;;
                system)
                    if [[ -n "$PKG_MGR" ]] && pkg_exists "$PROGRAM" "$PKG_MGR"; then
                        status "$PROGRAM found in $PKG_MGR"
                        if pkg_install "$PROGRAM" "$PKG_MGR"; then
                            manifest_add "$PROGRAM" "$PKG_MGR"
                            status_src "$PROGRAM installed" "$PKG_MGR"
                            installed=true
                        fi
                    fi
                    ;;
                repo)
                    curl -sSL --fail --head "https://raw.githubusercontent.com/$GITHUB_USER/$PROGRAM/main/install.sh" >/dev/null 2>&1 &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        printf "\r"
                        curl -sSL "https://raw.githubusercontent.com/$GITHUB_USER/$PROGRAM/main/install.sh" | bash
                        manifest_add "$PROGRAM" "repo"
                        status_src "$PROGRAM installed" "repo"
                        installed=true
                    fi
                    ;;
                wrapper)
                    curl -sSL --fail --head "$SAT_BASE/cargo-bay/programs/${PROGRAM}.sh" >/dev/null 2>&1 &
                    spin "Installing $PROGRAM" $!
                    if wait $!; then
                        printf "\r"
                        source <(curl -sSL "$SAT_BASE/internal/fetcher.sh")
                        sat_init
                        sat_run "$PROGRAM"
                        manifest_add "$PROGRAM" "wrapper"
                        status_src "$PROGRAM installed" "wrapper"
                        installed=true
                    fi
                    ;;
            esac
        done

        $installed || status "$PROGRAM not found"
    done
}
