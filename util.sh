#!/usr/bin/env bash
# this file should be sourced by all scripts.

# set to true to enable interactive prompts
INTERACTIVE=false

# check dependencies specified in DEPS
(
satis=true
for dep in "${DEPS[@]}"; do
    which "$dep" &> /dev/null ||
        echo -e "$BASH_SOURCE[1] requires $dep, but it could not be found" >&2 &&
        satis=false
done
$satis || exit 1
)

y-or-n-p() {
    # prints prompt to stderr and reads input from stdin. case-insensitive.
    $INTERACTIVE || return 0

    local prompt input
    prompt="$1"
    echo -en "${prompt}(y or n): " >&2
    read -r input
    input="${input,,}" # downcase. man:bash(1) Parameter Exapnsion : Case modification
    return $([ "yes" = "$input" ] || [ "y" = "$input" ])
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
