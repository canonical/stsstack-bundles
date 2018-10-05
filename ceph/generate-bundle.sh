#!/bin/bash -eu
# imports
. `dirname $0`/common/helpers.sh

# vars
opts=(
--template ceph.yaml.template
--path $0
)

# defaults
#parameters[]=


while (($# > 0))
do
    case "$1" in
        --graylog)
            overlays+=( "graylog.yaml ")
            ;;
        --rgw)
            overlays+=( "ceph-rgw.yaml" )
            ;;
        --rgw-multisite)
            overlays+=( "ceph-rgw.yaml" )
            overlays+=( "ceph-rgw-multisite.yaml" )
            ;;
        *)
            opts+=( $1 )
            ;;
    esac
    shift
done

generate
