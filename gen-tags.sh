#!/usr/bin/env bash
# -*- explicit-shell-file-name: /bin/bash; -*-

run() {
    # key : val
    # dir : extra args
    local -A targs
    local -a tags

    # local pub="minkernel/published"
    # local one="onecore"
    # local ntos="minkernel/ntos"
    # targs["$PWD/minkernel/published/ddk"]="--language-force=C"
    # targs["$PWD/minkernel/published/base"]="--language-force=C"
    # targs["$PWD/minkernel/published/sdk"]="--language-force=C"
    # targs["$PWD/onecore/base/tools/dsf/src/inc"]=
    # targs["$PWD/onecore/drivers/storage/port/raid"]=
    # targs["$PWD/onecore/drivers/published"]="--language-force=C"
    # targs["$PWD/minkernel/ntos/io"]=
    # targs["$PWD/minkernel/ntos/rtl"]=
    # targs["$PWD/sdktools/debuggers/exts/badev/extdll"]=
    # targs["$PWD/minkernel/storage"]=
    # targs["$PWD/minkernel/ntos/ke"]=
    # targs["$PWD/minkernel/ntos/whea"]=
    # targs["$PWD/minkernel/ntos/inc"]=
    # targs["$PWD/minkernel/published/internal"]="--language-force=C"
    targs[]

    local dir args
    for dir in "${!targs[@]}"; do
        [ ! $dir ] && continue

        args="${targs[$dir]}"

        # replace / with !
        local tagfile; tagfile=$(sed "s/\//\!/g" <<< $dir);
        tagfile="TAGS_$tagfile"
        tags+=("--etags-include=$tagfile")

        echo "tagging $dir" >&2

        local cmd="
ctags-exuberant -o $tagfile
-eR
-I _IRQL_requires_max_+
-I __drv_allocatesMem+
-I _IRQL_requires_min_+
-I _IRQL_requires_same_
-I _Must_inspect_result_
$args
$dir
"
        eval $cmd
        
    done

    # finally, create a single unified TAGS file with references to all
    ctags-exuberant -e -o TAGS "${tags[@]}" .
}


run
