#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# This list provides a way to set "internal opts" i.e. the ones accepted by
# the top-level generate-bundle.sh. The need to modify these should be rare.
declare -a opts=(
--internal-template ceph.yaml.template
--internal-generator-path `dirname $0`
)

# Series & Release Info (see http://docs.ceph.com/docs/master/releases/)
cat << 'EOF' > $f_rel_info
declare -A app_versions=( [firefly]=icehouse
                          [jewel]=mitaka
                          [luminous]=pike
                          [mimic]=rocky )
EOF
cat $LIB_COMMON/openstack_release_info.sh >> $f_rel_info

# Array list of overlays to use with this deployment.
declare -a overlays=()

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
declare -A parameters=()
parameters[__OS_ORIGIN__]=$os_origin
parameters[__SOURCE__]=$source
parameters[__NUM_CEPH_MON_UNITS__]=1
parameters[__NUM_VAULT_UNITS__]=1  # there are > 1 vault* overlay so need to use a global with default
parameters[__SSL_CA__]=
parameters[__SSL_CERT__]=
parameters[__SSL_KEY__]=

trap_help ${CACHED_STDIN[@]:-""}
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
        --num-mons|--num-ceph-mons)  #__OPT__type:<int>
            parameters[__NUM_CEPH_MON_UNITS__]=$2
            shift
            ;;
        --ssl)
            if ! `has_opt '--replay' ${CACHED_STDIN[@]}`; then
                (cd ssl; ./create_ca_cert.sh ceph;)
                ssl_results="ssl/ceph/results"
                parameters[__SSL_CA__]=`base64 ${ssl_results}/cacert.pem| tr -d '\n'`
                parameters[__SSL_CERT__]=`base64 ${ssl_results}/servercert.pem| tr -d '\n'`
                parameters[__SSL_KEY__]=`base64 ${ssl_results}/serverkey.pem| tr -d '\n'`
                # Make everything HA with 1 unit (unless --ha has already been set)
                if ! `has_opt '--rgw-ha[:0-9]*$' ${CACHED_STDIN[@]}`; then
                    set -- $@ --rgw-ha:1
                fi
            fi
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
        --vault)
            assert_min_release queens "vault" $@
            overlays+=( "vault.yaml" )
            overlays+=( "vault-ceph.yaml" )
            ;;
        --vault-ha*)
            get_units $1 __NUM_VAULT_UNITS__ 3
            overlays+=( "vault-ha.yaml" )
            set -- $@ --vault
            ;;
        --list-overlays)   #__OPT__
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
