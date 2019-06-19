#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# This list provides a way to set "internal opts" i.e. the ones accepted by
# the top-level generate-bundle.sh. The need to modify these should be rare.
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

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
parameters[__NUM_CEPH_MON_UNITS__]=1
parameters[__K8S_CHANNEL__]="latest/stable"
if ! `has_opt '--use-stable-charms' ${CACHED_STDIN[@]:-""}`; then
    opts+=( "--charm-channel edge" )
fi

trap_help ${CACHED_STDIN[@]:-""}
while (($# > 0))
do
    case "$1" in
        --k8s-channel)
            # which Kubernetes channel to set on deployment
            parameters[__K8S_CHANNEL__]="$2"
            shift
            ;;
        --ceph)
            overlays+=( "ceph.yaml" )
            overlays+=( "k8s-ceph.yaml" )
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
