#!/usr/bin/env bash
# == UNIVERSAL aliases ==

reload() {
    source ~/.bashrc
    $BASHRC/bin/lib/reload.sh "$@"
}

ensure-dirs() {
    $BASHRC/bin/lib/ensure-dirs.sh "$@"
}

alias eup='$EDITOR $BASHRC/modules/universal/paths.sh'
alias eua='$EDITOR $BASHRC/modules/universal/aliases.sh'
alias el='$EDITOR $BASHRC/modules/local.sh'





#------------------------------------------------------

# Basic ls aliases
alias ll='exa -alF'
alias la='exa -a'
alias l='exa -F'
alias ls='exa'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
