#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Globals
export INTERNAL_MODULE_PATH=`dirname $0`
export INTERNAL_BASE_TEMPLATE=landscape.yaml.template

# Collection of messages to display at the end
declare -a msgs=()

# This list provides a way to set "internal opts" i.e. the ones accepted by
# the top-level generate-bundle.sh. The need to modify these should be rare.
declare -a opts=()

# Series & Release Info
cat << 'EOF' > $f_rel_info
declare -A lts=( [xenial]=landscape
                 [bionic]=landscape )
declare -A nonlts=( [cosmic]=landscape
                    [disco]=landscape )
EOF

# Array list of overlays to use with this deployment.
declare -a overlays=()

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
declare -A parameters=()
parameters[__LANDSCAPE_VERSION__]="19.01"

trap_help $@
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

print_msgs
generate $f_rel_info
