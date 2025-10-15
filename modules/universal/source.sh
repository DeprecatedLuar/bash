#!/bin/bash
# Bash configuration magazine

# Ensure local configuration files exist
mkdir -p ~/.config/bash/modules/local
touch ~/.config/bash/modules/local/aliases.sh
touch ~/.config/bash/modules/local/paths.sh

# Source all module files
source ~/.config/bash/modules/universal/paths.sh
source ~/.config/bash/modules/defaults/defaults.sh
source ~/.config/bash/modules/universal/aliases.sh
# Source local files
source ~/.config/bash/modules/local/paths.sh
source ~/.config/bash/modules/local/aliases.sh

# Initialize zoxide (suppress write permission errors)
eval "$(zoxide init bash)"

# Source bash completions
if [ -d "$TOOLS/bin/completions" ]; then
    for completion in "$TOOLS/bin/completions"/*; do
        [ -f "$completion" ] && source "$completion"
    done
fi

