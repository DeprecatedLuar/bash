#!/usr/bin/env bash
# Bash configuration magazine

# Ensure local configuration file exists
touch ~/.config/bash/modules/local.sh

# Source all module files
source ~/.config/bash/modules/universal/xdg.sh
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
export XDG_DESKTOP_DIR XDG_DOWNLOAD_DIR XDG_DOCUMENTS_DIR XDG_PICTURES_DIR XDG_VIDEOS_DIR XDG_MUSIC_DIR XDG_TEMPLATES_DIR XDG_PUBLICSHARE_DIR
source ~/.config/bash/modules/universal/paths.sh
source ~/.config/bash/modules/defaults/defaults.sh
source ~/.config/bash/modules/universal/aliases.sh
source ~/.config/bash/modules/local.sh

# Initialize zoxide (suppress write permission errors)
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# Source bash completions
if [ -d "$TOOLS/bin/completions" ]; then
    for completion in "$TOOLS/bin/completions"/*; do
        [ -f "$completion" ] && source "$completion"
    done
fi

