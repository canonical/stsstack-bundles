#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# This list provides a way to set "internal opts" i.e. the ones accepted by
# the top-level generate-bundle.sh. The need to modify these should be rare.
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

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
parameters[__LANDSCAPE_VERSION__]="19.01"

trap_help ${CACHED_STDIN[@]:-""}
while (($# > 0))
do
    case "$1" in
        --landscape-version)  #__OPT__type:<int>
            parameters[__LANDSCAPE_VERSION__]=$2
            shift
            ;;
        --ha)
            overlays+=( "landscape-ha.yaml" )
            ;;
        --list-overlays)  #__OPT__
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
