#!/bin/bash -eu
# imports
. `dirname $0`/common/helpers.sh

# vars
opts=(
--template kubernetes.yaml.template
--path $0
)

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

generate
