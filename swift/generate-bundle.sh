#!/bin/bash -eu
# imports
. `dirname $0`/common/helpers.sh

# vars
opts=(
--internal-template swift.yaml.template
--internal-generator-path $0
)
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Series & Release Info
cat << 'EOF' > $f_rel_info
EOF
cat `dirname $0`/common/openstack_release_info.sh >> $f_rel_info

# defaults
#parameters[]=
overlays+=( swift.yaml )


while (($# > 0))
do
    case "$1" in
        --graylog)
            overlays+=( "graylog.yaml ")
            ;;
        --vault)
            overlays+=( "vault.yaml" )
            overlays+=( "vault-swift.yaml" )
            ;;
        --ha*)
            get_units $1 __NUM_SWIFT_PROXY_UNITS__ 3
            overlays+=( "swift-ha.yaml" )
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
