#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# vars
opts=(
--internal-template landscape.yaml.template
--internal-generator-path $0
)
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Series & Release Info
cat << 'EOF' > $f_rel_info
declare -A lts=( [xenial]=landscape
                 [bionic]=landscape )
declare -A nonlts=( [cosmic]=landscape
                    [disco]=landscape )
EOF

# defaults
parameters[__LANDSCAPE_VERSION__]="19.01"

trap_help ${CACHED_STDIN[@]:-""}
while (($# > 0))
do
    case "$1" in
        --landscape-version)  #type:<int>
            parameters[__LANDSCAPE_VERSION__]=$2
            shift
            ;;
        --ha)
            overlays+=( "landscape-ha.yaml" )
            ;;
        --list-overlays)
            list_overlays
            exit
            ;;
        *)
            opts+=( $1 )
            ;;
    esac
    shift
done

generate $f_rel_info
