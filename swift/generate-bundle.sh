#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

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
cat $LIB_COMMON/openstack_release_info.sh >> $f_rel_info

# defaults
#parameters[]=
overlays+=( swift.yaml )

trap_help ${CACHED_STDIN[@]}
while (($# > 0))
do
    case "$1" in
        --graylog)
            overlays+=( "graylog.yaml ")
            ;;
        --lma)
            # Logging Monitoring and Analysis
            overlays+=( "graylog.yaml ")
            msgs+=( "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor" )
            overlays+=( "grafana.yaml ")
            msgs+=( "NOTE: you will need to manually relate grafana (telegraf) to any services you want to monitor" )
            ;;
        --vault)
            assert_min_release queens "vault" $@
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
