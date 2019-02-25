#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# vars
opts=(
--internal-template kubernetes.yaml.template
--internal-generator-path $0
)
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Series & Release Info
cat << 'EOF' > $f_rel_info
declare -A lts=( [bionic]=cdk )
declare -A nonlts=( [cosmic]=cdk
                    [disco]=cdk )
EOF

# defaults
#parameters[]=


while (($# > 0))
do
    case "$1" in
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
