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
--internal-template swift.yaml.template
--internal-module-path `dirname $0`
)

# Series & Release Info
cat $LIB_COMMON/openstack_release_info.sh > $f_rel_info

# Array list of overlays to use with this deployment.
declare -a overlays=()
# We always add this overlay since it contains core apps for this module.
overlays+=( swift.yaml )

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
declare -A parameters=()
parameters[__OS_ORIGIN__]=$os_origin
parameters[__SOURCE__]=$source
parameters[__NUM_VAULT_UNITS__]=1  # there are > 1 vault* overlay so need to use a global with default
parameters[__SSL_CA__]=
parameters[__SSL_CERT__]=
parameters[__SSL_KEY__]=
parameters[__NUM_ETCD_UNITS__]=1
parameters[__ETCD_SNAP_CHANNEL__]='latest/stable'

trap_help ${CACHED_STDIN[@]:-""}
while (($# > 0))
do
    case "$1" in
        --graylog)
            overlays+=( "graylog.yaml ")
            ;;
        --lma)
            # Logging Monitoring and Alarming
            overlays+=( "graylog.yaml ")
            msgs+=( "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor" )
            overlays+=( "grafana.yaml ")
            msgs+=( "NOTE: you will need to manually relate grafana (telegraf) to any services you want to monitor" )
            ;;
        --ssl)
            if ! `has_opt '--replay' ${CACHED_STDIN[@]}`; then
                (cd ssl; ./create_ca_cert.sh swift;)
                ssl_results="ssl/swift/results"
                parameters[__SSL_CA__]=`base64 ${ssl_results}/cacert.pem| tr -d '\n'`
                parameters[__SSL_CERT__]=`base64 ${ssl_results}/servercert.pem| tr -d '\n'`
                parameters[__SSL_KEY__]=`base64 ${ssl_results}/serverkey.pem| tr -d '\n'`
                # Make everything HA with 1 unit (unless --ha has already been set)
                if ! `has_opt '--ha[:0-9]*$' ${CACHED_STDIN[@]}`; then
                    set -- $@ --ha:1
                fi
            fi
            ;;
        --vault)
            assert_min_release queens "vault" $@
            overlays+=( "vault.yaml" )
            overlays+=( "vault-swift.yaml" )
            ;;
        --etcd-channel)
            parameters[__ETCD_SNAP_CHANNEL__]=$2
            shift
            ;;
        --vault-ha*)
            get_units $1 __NUM_VAULT_UNITS__ 3
            get_units $1 __NUM_ETCD_UNITS__ 3
            overlays+=( "vault-ha.yaml" )
            overlays+=( "etcd.yaml" )
            overlays+=( "easyrsa.yaml" )
            overlays+=( "etcd-easyrsa.yaml" )
            overlays+=( "vault-etcd.yaml" )
            set -- $@ --vault
            ;;
        --ha*)
            get_units $1 __NUM_SWIFT_PROXY_UNITS__ 3
            overlays+=( "swift-ha.yaml" )
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
