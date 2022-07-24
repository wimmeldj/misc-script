#!/usr/bin/env bash
# -*- explicit-shell-file-name: /bin/bash; -*-

#
# ctags --list-kinds-full c | awk '$1 == "C" { print; } NR == 1 { print; }' run
#
# above to get "kinds" of tags. Exclude or disclude a tag kind with
# --kinds-C=+{addKind} or --kinds-C=-{remKind}
#
# e.g. --kinds-C=+{label}{prototype} tells c-tags to generate tags for labels
# and prototypes which isn't done by default
#
# 
# A not uncommon phenomenon is for macros placed before relevant symbol
# declares/defns to screw up the ctags parser. To remedy this, you can instruct
# ctags to ignore the macro usage.
#
# -I IDENTIFIER  - to ignore the identifier
# -I IDENTIFIER+ - to ignore the identifier and any paren enclosed args
#
# e.g.
# https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/irql-annotations-for-drivers
#
# -I _IRQL_requires_same_ to ignore : _IRQL_requires_same_ fun(...);
# -I _IRQL_requires_max_+  to ignore: _IRQL_requires_max_(irql) fun(...);
#
# See Man:ctags(1) for syntax to provide this list as a file if you'd rather
#

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
    targs["$PWD/urbit"]=
    targs["$PWD/urcrypt"]=
    targs["$PWD/ent"]=
    targs["$PWD/hs"]=
    # parsing the whole /usr/include causes lookup to take > 1 sec.
    targs["/usr/include/uv.h"]="--language-force=C"
    targs["/usr/include/uv"]=

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
ctags -o $tagfile
-eR
--kinds-C=+{label}{prototype}
$args
$dir
"
        eval $cmd

    done

    # finally, create a single unified TAGS file with references to all
    ctags -e -o TAGS "${tags[@]}" .
}


run
