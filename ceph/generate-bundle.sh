#!/bin/bash -eu
# imports
. `dirname $0`/common/helpers.sh

# vars
opts=(
--template ceph.yaml.template
--path $0
)

# defaults
parameters[__NUM_CEPH_MON_UNITS__]=1


while (($# > 0))
do
    case "$1" in
        --graylog)
            overlays+=( "graylog.yaml ")
            ;;
        --mon-ha*|--ceph-mon-ha*)
            get_units $1 __NUM_CEPH_MON_UNITS__ 3
            overlays+=( "ceph-mon-ha.yaml" )
            ;;
        --rgw|--ceph-rgw)
            overlays+=( "ceph-rgw.yaml" )
            ;;
        --rgw-ha*|--ceph-rgw-ha*)
            get_units $1 __NUM_CEPH_RGW_UNITS__ 3
            overlays+=( "ceph-rgw.yaml" )
            overlays+=( "ceph-rgw-ha.yaml" )
            ;;
        --rgw-multisite|--ceph-rgw-multisite)
            overlays+=( "ceph-rgw.yaml" )
            overlays+=( "ceph-rgw-multisite.yaml" )
            ;;
        --rgw-multisite-ha*|--ceph-rgw-multisite*)
            get_units $1 __NUM_CEPH_RGW_UNITS__ 3
            overlays+=( "ceph-rgw.yaml" )
            overlays+=( "ceph-rgw-ha.yaml" )
            overlays+=( "ceph-rgw-multisite.yaml" )
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

generate
