#!/usr/bin/bash
# -*- explicit-shell-file-name: /bin/bash; -*-


#### ===========================================================================
####                                    sourcing

BASE_DIR=$(dirname "${BASH_SOURCE[0]}")
DEPS=(
    awk
     )
source "${BASE_DIR:-.}/util.sh"


#### ===========================================================================
####                                    globals

NSPACE="auto"
ZFSP_CREATEDBY=":${NSPACE}-createdby"
ZFS_BACKUPID="${NSPACE}-backup"


#### ===========================================================================
####                                    provides

# TODO allow non recursive? just accept a param splicing additional args?
zfs-recursive-snap-ts() (
    set -e
    local usage; usage=$(cat <<EOF
Create a timestamped recursive snapshot of a filesystem. Prints name of snapshot
created to stdin.

Usage: ${FUNCNAME[0]} [-i] [-n CREATEDBY] FS

-n NAME     creates the snapshot with the zfsprop "$ZFSP_CREATEDBY" set to NAME
-i          interactive. Prompts with name and confirmation.
EOF
          )
    local INTERACTIVE=false
    local createdby
    local opt OPTIND OPTARG
    while getopts ":in:h" opt; do
        case "$opt" in
            n) createdby="$OPTARG";;
            i) INTERACTIVE=true;;
            h) echo "$usage" && return 0;;
            *) echo "$usage" && return 1;;
        esac
    done
    shift $((OPTIND - 1))
    [ $# != 1 ] && echo "$usage" && return 1;

    local fs="$1"
    local ts; ts=$(date +%Y.%m.%d-%H:%M:%S) # YYYY.MM.DD-HH:MM:SS
    local snapname="${fs}@${ts}"

    [ -z "$createdby" ] &&
        cmd="zfs snapshot -r \"$snapname\"" ||
            cmd="zfs snapshot -r -o \"${ZFSP_CREATEDBY}=${createdby}\" \"$snapname\""

    y-or-n-p "Create snapshot with:\n\t$cmd ?\n" &&
        eval "$cmd" &&
        echo "$snapname"
)

zfs-list-if() {
    local usage; usage=$(cat <<EOF
Wrapper around zfs-list to only output data where PROP=VALUE

Usage ${FUNCNAME[0]} PROP VALUE ZFS-LIST-ARGS

See man:zfs-list(8) for ZFS-LIST-ARGS.
EOF
          )
    # default props printed man:zfs-list(8)
    local props="name,used,available,referenced,mountpoint"
    local want_header=1
    local prop value unhandled_args
    prop="$1"; value="$2"; shift 2

    while [ "$#" -gt 0 ]; do
        case $1 in
            -H )
                want_header=0;
                unhandled_args="$unhandled_args $1";
                shift;;
            -o )
                [ "${2:0:1}" == "-" ] && echo "$usage" && return 1;
                props="$2"; shift 2;;
            -h )
                echo "$usage" && return 0;;
            -s|-S|-d|-t )
                unhandled_args="$unhandled_args $1 $2";
                shift 2;;
            * )
                unhandled_args="$unhandled_args $1"
                shift;;
        esac
    done

    eval "zfs list -o $prop,$props $unhandled_args" |
        awk '
(NR == 1 && '$want_header') {
    # print header without filtered prop name
    header = substr($0, length("'"$prop"'") + 1)
    match(header, /^[[:space:]]*/)
    print substr(header, RLENGTH + 1)
}
($1 == "'"$value"'") {
    # print data without filtered prop value
    row = substr($0, length("'"$value"'") + 1)
    match(row, /^[[:space:]]*/)
    print substr(row, RLENGTH + 1)
}'
}

zfs-backup() (
    set -e
    local usage; usage=$(cat <<EOF
Backup a filesystem to another filesystem using zfs-send and zfs-receive. This
is most useful when the filesystems reside in different pools. This is done
using incremental recursive snapshots that have the "$ZFSP_CREATEDBY" prop set
to "$ZFS_BACKUPID"; One incremental snapshot for both src and sink filesystems
will be kept. If either of these are deleted, or this is your first time running
${FUNCNAME[0]}, a full stream will be sent to the sink and matching snapshots
will generated for both.

Usage: ${FUNCNAME[0]} [-i] SRC SINK

-i     interactive. perhaps we don't want interactive

TODO
The variables _SEND_ARGS and ZFS_RECV_ARGS can be used to splice additional
arguments into the send and receive commands.
EOF
          )
    # TODO trap SIGINT and also handle a failure to send | recv the same It
    # should do: prompt? send/recv failed, do you want to destroy the snapshot
    # created?
    local src sink
    local INTERACTIVE=false
    local opt OPTIND OPTARG
    while getopts ":ih" opt; do
        case $opt in
            i) INTERACTIVE=true;;
            h) echo "$usage" && return 0;;
            *) echo "$usage" && return 1;;
        esac
    done
    shift $((OPTIND - 1))
    [ $# != 2 ] && echo "$usage" && return 1;
    src="$1"; sink="$2"         # TODO validate these are actually filesystems

    local newsnap
    # TODO this probably shouldn't be a choice. It's required
    if y-or-n-p "Create timestamped recursive backup of $src? "; then
        newsnap=$(zfs-recursive-snap-ts -n "$ZFS_BACKUPID" "$src")
    else
        return 0
    fi

    # snaps created by us sorted most to least recently created
    src_tab=$(zfs-list-if "$ZFSP_CREATEDBY" "$ZFS_BACKUPID" \
                            -H -t snapshot -S creation -o guid,name "$src")
    sink_tab=$(zfs-list-if "$ZFSP_CREATEDBY" "$ZFS_BACKUPID" \
                             -H -t snapshot -S creation -o guid,name "$sink")

    local -A src_rels sink_rels
    local -a src_guids shared_guids
    local guid name
    while IFS=$'\t' read -r guid name; do
        [ -z "$guid" ] && continue
        src_rels["$guid"]="$name"
        src_guids+=("$guid")
    done <<< "$src_tab"

    while IFS=$'\t' read -r guid name; do
        [ -z "$guid" ] && continue
        [ -n "${src_rels[$guid]}" ] && shared_guids+=("$guid")
        sink_rels["$guid"]="$name"
    done <<< "$sink_tab"

    local cmd
    local latest_src_snap="${src_rels[$src_guids]}"
    if [ ${#shared_guids[@]} -gt 0 ]; then
        local latest_shared_snap="${src_rels[$shared_guids]}"
        # TODO when printing, only inlcude the part after "@".
        echo "$src and $sink appear to share one or more snapshots. This is the most recent:
$latest_shared_snap

These snapshots were taken after it:" >&2
        for guid in "${src_guids[@]}"; do
            [ "${src_rels[$guid]}" == "$latest_shared_snap" ] && break
            echo -e "\t${src_rels[$guid]}" >&2
        done

        cmd="zfs send $ZFS_SEND_ARGS -R -I $latest_shared_snap $latest_src_snap | \
zfs receive $ZFS_RECV_ARGS $sink"
        y-or-n-p "Send incremental backup of snapshots from $src to $sink with:\n\t$cmd ?\n" &&
            eval "$cmd" ||
                return 0

        local n; n=$(choose-num -n 1 "Cleanup all but the n most recent snapshots from src?")
        # TODO cleanup. Should we ask N on src and M on sink?
        declare -p n && return 0
    else
        echo "$src and $sink do not appear to share any snapshots." >&2
        cmd="zfs send $ZFS_SEND_ARGS -R $latest_src_snap | zfs receive $ZFS_RECV_ARGS $sink"
        y-or-n-p "Send full replication stream from $src to $sink with:\n\t$cmd ?\n" &&
            eval "$cmd"
    fi
)

# zfs send -v -R -I
# ssd-raid0/full-nodes@23.01.2021-03:44:55 the earliest snap
# ssd-raid0/full-nodes@2021.03.31-01:41:46 the latest snap
# | zfs receive -v backup-seagate2tb/full-nodes

# specify -F in zfs recv if you want to force a rollback of the base filesystem

# use zfs hold to prevent destruction of these snpashots maybe
