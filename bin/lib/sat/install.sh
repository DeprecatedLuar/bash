#!/usr/bin/env bash
# sat install - install programs from various sources

sat_install() {
    local PKG_MGR=$(get_pkg_manager)

    for PROGRAM in "$@"; do
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
                status "$REPO_NAME installed via $REPO_PATH"
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
                status "$REPO_NAME installed via $REPO_PATH"
                continue
            fi

            status "$REPO_NAME install.sh not found"
            continue
        fi

        # 0. Check if already installed
        if command -v "$PROGRAM" &>/dev/null; then
            status "$PROGRAM already installed"
            continue
        fi

        printf "Installing %s" "$PROGRAM"

        # 1. Try native package manager
        if [[ -n "$PKG_MGR" ]] && pkg_exists "$PROGRAM" "$PKG_MGR"; then
            status "$PROGRAM found in $PKG_MGR"
            if pkg_install "$PROGRAM" "$PKG_MGR"; then
                manifest_add "$PROGRAM" "$PKG_MGR"
                status "$PROGRAM installed via $PKG_MGR"
                continue
            fi
        fi

        # 2. Try repo install.sh
        curl -sSL --fail --head "https://raw.githubusercontent.com/$GITHUB_USER/$PROGRAM/main/install.sh" >/dev/null 2>&1 &
        spin "Installing $PROGRAM" $!
        if wait $!; then
            printf "\r"
            curl -sSL "https://raw.githubusercontent.com/$GITHUB_USER/$PROGRAM/main/install.sh" | bash
            manifest_add "$PROGRAM" "repo"
            status "$PROGRAM installed via repo"
            continue
        fi

        # 3. Try uv tool (isolated Python CLI)
        if command -v uv &>/dev/null; then
            uv tool install "$PROGRAM" &>/dev/null &
            spin "Installing $PROGRAM" $!
            if wait $!; then
                manifest_add "$PROGRAM" "uv"
                status "$PROGRAM installed via uv"
                continue
            fi
        fi

        # 4. Try npm (Node CLI)
        if command -v npm &>/dev/null && npm show "$PROGRAM" >/dev/null 2>&1; then
            npm install -g "$PROGRAM" &>/dev/null &
            spin "Installing $PROGRAM" $!
            if wait $!; then
                manifest_add "$PROGRAM" "npm"
                status "$PROGRAM installed via npm"
                continue
            fi
        fi

        # 5. Try satellite wrapper (last resort)
        curl -sSL --fail --head "$SAT_BASE/cargo-bay/programs/${PROGRAM}.sh" >/dev/null 2>&1 &
        spin "Installing $PROGRAM" $!
        if wait $!; then
            printf "\r"
            source <(curl -sSL "$SAT_BASE/internal/fetcher.sh")
            sat_init
            sat_run "$PROGRAM"
            manifest_add "$PROGRAM" "wrapper"
            status "$PROGRAM installed via wrapper"
            continue
        fi

        status "$PROGRAM not found"
    done
}
