#!/bin/bash

# Source this file inside ~/.bashrc
# or run `echo 'source <path to this script>/custom-bash-prompt.sh' >> ~/.bashrc`
#
# In WSL via Win11 terminal app, download a NerdFont and install it on Windows,
# Download FiraCode: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FiraCode.zip
# Unzip and install FiraCodeNerdFontMono-Regular.ttf,
# Restart the terminal app,
# then in terminal app settings > Profiles > Ubuntu 24.04.1 LTS > Appearance > Font face > Show all fonts > FiraCode Nerd Font Mono
#
# If the conda label appeared redundantly above the prompt, it's because of the default conda config activated by bashrc, 
# just run this once and it gets fixed: "~$ conda config --set changeps1 false"
#
# Icons if needed
# - OS        :     
# - Folder    :  
# - Git branch: 
# - Arrow     : 󱞩 󰁕 󱦰  󰁔 
# - Seperator : 


colorize(){
    echo "\001$1\002"
}

BOLD=$(colorize $(tput bold))
RESET=$(colorize $(tput sgr0))

BLACK_FG=$(colorize $(tput setaf 235))
BLACK_BG=$(colorize $(tput setab 235))

YELLOW_FG=$(colorize $(tput setaf 172))
YELLOW_BG=$(colorize $(tput setab 172))

BLUE_FG=$(colorize $(tput setaf 69))
BLUE_BG=$(colorize $(tput setab 69))

GREEN_FG=$(colorize $(tput setaf 2))
GREEN_BG=$(colorize $(tput setab 2))

LIT_YELLOW_FG=$(colorize $(tput setaf 227))
LIT_YELLOW_BG=$(colorize $(tput setab 227))

PS1="\n"
PS1+="${BLUE_BG}${BLACK_FG} ${RESET}"        # Tag 
PS1+="${GREEN_BG}${BLUE_FG}${RESET}"        # Wedge
PS1+="${GREEN_BG}${BLACK_FG}  \${CONDA_DEFAULT_ENV:-}${RESET}"   # Conda Tag
PS1+="${YELLOW_BG}${GREEN_FG}${RESET}"       # Wedge 
PS1+="${YELLOW_BG}${BLACK_FG}  \w ${RESET}"  # Tag

# Blue
#PS1+="${BLUE_BG}${YELLOW_FG}"                # Wedge
#PS1+="${BLUE_BG}${BLACK_FG}${BOLD}"
#PS1+='$(__git_ps1 "  %s ")'"${RESET}"        # Git Tag
#PS1+="${BLUE_FG}${RESET}"                    # Last Wedge

# Yellow
#PS1+="${LIT_YELLOW_BG}${YELLOW_FG}"                # Wedge
#PS1+="${LIT_YELLOW_BG}${BLACK_FG}${BOLD}"
#PS1+='$(__git_ps1 "  %s ")'"${RESET}"        # Git Tag
#PS1+="${LIT_YELLOW_FG}${RESET}"                    # Last Wedge


# Conditional block
__git_block() {
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
                printf '%s' "${__GB_YL}$(__git_ps1 "  %s ")${__GB_YR}"
        else
                printf '%s' "${__GB_BL}$(__git_ps1 "  %s ")${__GB_BR}"
        fi
}
__GB_YL="${LIT_YELLOW_BG}${YELLOW_FG}${LIT_YELLOW_BG}${BLACK_FG}${BOLD}"
__GB_YR="${RESET}${LIT_YELLOW_FG}${RESET}"
__GB_BL="${BLUE_BG}${YELLOW_FG}${BLUE_BG}${BLACK_FG}${BOLD}"
__GB_BR="${RESET}${BLUE_FG}${RESET}"
for __v in __GB_YL __GB_YR __GB_BL __GB_BR; do
        __t="${!__v}"
        __t="${__t//'\001'/$'\001'}"
        __t="${__t//'\002'/$'\002'}"
        declare -g "$__v=$__t"
done
unset __v __t
PS1+='$(__git_block)'



# The bottom snippet
PS1+=$'\n'
PS1+="${YELLOW_FG}󱞩  ${RESET}"

trap "tput sgr0" DEBUG

unset -f colorize

unset BOLD
unset RESET
unset BLACK_FG
unset BLACK_BG
unset YELLOW_FG
unset YELLOW_BG
unset BLUE_FG
unset BLUE_BG
unset GREEN_FG 
unset GREEN_BG
unset LIT_YELLOW_FG 
unset LIT_YELLOW_BG
