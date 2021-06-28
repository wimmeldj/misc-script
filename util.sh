#!/usr/bin/env bash
# -*- explicit-shell-file-name: /bin/bash; -*-

#### ===========================================================================
####                                  general util

# TODO bold and or colored text for prompt functions
y-or-n-p() {
    # usage: y-or-n-p [PROMPT]
    # prints prompt to stderr and reads input from stdin. case-insensitive.
    $INTERACTIVE || return 0

    local prompt input
    prompt="$1"
    echo -en "${prompt} (y or n): " >&2
    while read -r input; do
        input="${input,,}" # downcase. man:bash(1) Parameter Exapnsion : Case modification
        case "$input" in
            yes|y) return 0 ;;
            no|n) return 1 ;;
            *) echo -en "${prompt} (y or n): " >&2 ;;
        esac
    done
}

is-num() {
    # usage: is-num N
    [ "$1" -eq "$1" ] && return 0 || return 1
}

n-of() {
    # usage: n-of N STR
    #
    # prints N of STR to stdout

    local N str
    N=$1; str=$2
    is-num "$N" || return 1
    [ "$N" -lt 0 ] && return 1
    if [ "$N" -eq 0 ]; then
        printf ""
    else
        eval "printf '$str%.0s' {1..$N}"
    fi
}

char-join() {
    # usage: char-join CHAR [WORDS ...]
    [ "${#1}" = 1 ] || return 1; # /char/ join
    local IFS="$1"; shift;
    echo "$*"
}

# like readarray aka mapfile but for associative arrays
# not all options implemented
# read-assoc() {
#     while getopts "in:h" opt; do
#         case "$opt" in
#             n) createdby="$OPTARG";;
#             i) INTERACTIVE=true;;
#             h) echo "$usage" && return 0;;
#             *) echo "$usage" && return 1;;
#         esac
#     done
#     shift $((OPTIND - 1))
#     while IFS= read -r
# }

# returns nth column. 1-indexed.
# usage: awk-nth N var
# awk-nth() { awk '{print $'"$1"'}' <<< "$2"; }

#### ===========================================================================
####                                  IO Handling

option-list() {
    # print args as a list of options
    #
    # usage: option-list [KEY VAL]...
    #
    # e.g.: option-list k1 v1 k2 v2 k13 v13
    # ->
    # [k1  ] v1
    # [k2  ] v2
    # [k100] v13

    (($# % 2 == 0)) || return 1 # every k has a v
    local -a args=("$@")

    local max_width i
    max_width=0
    for ((i=0; i < $#; i+=2)); do
        [ "${#args[i]}" -gt "$max_width" ] && max_width="${#args[i]}"
    done

    local k v padding ret
    for ((i=0; i < $#; i+=2)); do
        k=${args[i]}
        v=${args[i+1]}
        padding=$((max_width - ${#k}))
        ret+="[${k}$(n-of $padding ' ')] ${v}"
        ((i + 2 < $# )) && ret+=$'\n'
    done
    echo "$ret"
}

# # TODO
# option-table() {
#     # print args as a table of options
#     #
#     # usage: option-table [-w WIDTH] [KEY VAL]...
#     #
#     # -w WIDTH max table width. if not provided, defaults to 80 chars
#     #
#     # e.g.: option-table -w 35 k1 v1 k2 v2 k3 v3 k10 v10 k700 v700
#     # ->
#     # [k1 ] v1    [k2  ] v2    [k3] v3
#     # [k10] v10   [k700] v700

#     # need awk. Is this really feasible? Consider long value strings and
#     # their effects
# }

choose() {
    # Prompt for user input.
    #
    # usage: choose [-n DEFAULT] [-p VALIDATION_PATTERN] PROMPT
    #               [INFO_KEY INFO_VAL]....
    #
    # -n DEFAULT If no input is received return DEFAULT instead of looping. If
    #    called non-interactively, this is required.
    #
    # -p VALIDATION_PATTERN Only return input =~ to VALIDATION_PATTERN

    local default msg vpat has_default has_info
    vpat=".*"                   # match all input by default
    has_default=false; has_info=false
    local opt OPTIND OPTARG
    while getopts ":n:p:" opt; do
        case "$opt" in
            n) default="$OPTARG";has_default=true;;
            p) vpat="$OPTARG";;
            *) return 1;
        esac
    done
    shift $((OPTIND - 1))
    # when called non-interactively, need explicit return value
    if ! $INTERACTIVE; then
        ! $has_default && return 1
        echo "$default" && return 0
    fi
    msg="$1"; shift;
    [ "$#" -gt 0 ] && has_info=true || has_info=false

    # construct prompt
    local S_DEFAULT="default: $default"
    local S_OPTIONS="? to list options"
    local prompt="$msg"
    if $has_default && $has_info; then
        prompt+=" ($S_DEFAULT, $S_OPTIONS)"
    elif $has_default; then
        prompt+=" ($S_DEFAULT)"
    elif $has_info; then
        prompt+=" ($S_OPTIONS)"
    fi
    prompt+=": "

    echo -en "$prompt" >&2
    local input
    while read -r input; do
        if [ -z "$input" ] && $has_default; then
            echo "$default" && return 0
        elif [ "$input" == "?" ] && $has_info; then
            option-list "$@" >&2
            echo -en "$prompt" >&2
        elif [[ "$input" =~ $vpat ]]; then
            echo "$input" && return 0
        else
            echo -en "$prompt" >&2
        fi
    done
}

choose-num() {
    # Prompt for a number using `choose'. Default need not be a number
    #
    # usage: choose-num [-n DEFAULT] PROMPT [INFO_KEY INFO_VAL]

    choose -p "^[0-9][0-9]*$" "$@"
}

spin-prompt() {
    # usage: spin-prompt [RUNNING-MSG] [FINISHED-MSG]
    #
    # prints a message with spinner while waiting for last executed proc to
    # finish.
    #
    # e.g. (do-something & spin-prompt waiting finished)
    $INTERACTIVE || return 0
    local prompt fin pid
    prompt=$1; fin=$2
    pid=$!

    local rest curr
    rest="\ | / -"
    while kill -0 $pid 2>/dev/null ; do
        read -r curr rest <<< "$rest"
        echo -en "\r\e[K${prompt:+$prompt }$curr" >&2
        rest+=" $curr"
        sleep 0.1
    done
    echo -e "\r\e[K$fin" >&2
}

spin-prompt-utf8() {
    # same as spin prompt but with fancy unicode chars
    $INTERACTIVE || return 0
    local prompt fin pid
    prompt=$1; fin=$2
    pid=$!

    local beg end cur
    beg=10303
    end=10495
    cur=$beg
    while kill -0 $pid 2>/dev/null; do
        [ $cur == $end ] && cur=$beg
        cur=$((cur + 1))
        echo -en $(printf "\\\\r\\\\e[K${prompt:+$prompt }\\\\U%X" $cur) >&2
        sleep 0.1
    done
    echo -e "\r\e[K$fin" >&2
}

#### ===========================================================================
####                                      main

check-deps() {
    # verifies all members in DEPS can be found in the current PATH
    local satis=true
    for dep in "${DEPS[@]}"; do
        which "$dep" &> /dev/null || {
            echo -e "${BASH_SOURCE[1]} requires $dep, but it could not be found" >&2 &&
            satis=false
        }
    done
    $satis || exit 1
}

# set to true to enable interactive prompts
INTERACTIVE=false

# always check dependencies
check-deps
