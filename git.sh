#!/usr/bin/bash
# -*- explicit-shell-file-name: /bin/bash; -*-

git-ssh-alias() {
    local usage; usage=$(cat <<EOF
Set the url of all git remotes in the current directory to a new host

Usage: ${FUNCNAME[0]} host

This is useful when you want to use different ssh keys for repos on the same
host. e.g.

in ~/.ssh/config:

Host github.com
     HostName github.com
     User git
     IdentityFile ~/.ssh/id_rsa

Host diff
     HostName github.com
     User git
     IdentityFile ~/.ssh/diff_rsa

./git-ssh-alias diff - make the repo use the diff_rsa key
EOF
                      )
    [ $# != 1 ] && echo "$usage" && return 1

    local host="$1"
    local mirror name url
    git remote -v |
        awk '
        $2 ~ /^https?:\/\// {
           sub(/^https?:\/\/[^\/]*?\//, "", $2);           # strip https://x.com/
           new_url = sprintf("git@%s:%s", "'"$host"'", $2) # git@HOST:url suffix
           print $3, $1, new_url;
        }
        $2 ~ /^git@/ {
           sub(/@[^:]*?/, "@'"$host"'", $2);               # rename host
           print $3, $1, $2;
        }' |
        while read -r mirror name url; do
            if [ "$mirror" = "(push)" ]; then
                git remote set-url --push "$name" "$url"
            else
                git remote set-url "$name" "$url"
            fi
        done
}
