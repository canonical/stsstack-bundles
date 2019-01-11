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

list_overlays ()
{
    echo "Supported overlays:"
    sed -r 's/.+\s+(--[[:alnum:]\-]+\*?).+/\1/g;t;d' `basename $0`| \
        egrep -v "\--list-overlays"
}


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
