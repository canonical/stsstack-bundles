#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh
f_rel_info=`mktemp`
msgs=()

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# This list provides a way to set "internal opts" i.e. the ones accepted by
# the top-level generate-bundle.sh. The need to modify these should be rare.
declare -a opts=(
--internal-template kubernetes.yaml.template
--internal-module-path `dirname $0`
)
if ! `has_opt '--charm-channel'` && \
        ! `has_opt '--use-stable-charms'`; then
    set -- $@ --charm-channel edge && cache $@
fi

# Series & Release Info
cat << 'EOF' > $f_rel_info
declare -A lts=( [bionic]=cdk )
declare -A nonlts=( [cosmic]=cdk
                    [disco]=cdk )
EOF

# Array list of overlays to use with this deployment.
declare -a overlays=()

# Bundle template parameters. These should correspond to variables set at the top
# of yaml bundle and overlay templates.
declare -A parameters=()
parameters[__NUM_CEPH_MON_UNITS__]=1
parameters[__K8S_CHANNEL__]="latest/stable"
parameters[__NUM_ETCD_UNITS__]=1
parameters[__NUM_K8S_MASTER_UNITS__]=1
parameters[__NUM_K8S_WORKER_UNITS__]=2
parameters[__NUM_K8S_LB_UNITS__]=1
parameters[__ETCD_SNAP_CHANNEL__]='latest/stable'

# default for current stable is to use containerd
# See https://ubuntu.com/kubernetes/docs/container-runtime
if ! `has_opt '--k8s-channel'` && \
       ! `has_opt '--docker'`; then
    set -- $@ --containerd && cache $@
fi

check_hacluster_channel ()
{
    charm_channel="`get_optval --charm-channel`"
    if [ -n "$charm_channel" ] && [ "$charm_channel" != "stable" ]; then
        # NOTE(dosaboy): https://bugs.launchpad.net/juju/+bug/1832873
        msgs+=( "\nIMPORTANT: you are using the $charm_channel charm channel but hacluster is not published to that channel. Either switch to stable channel or post-upgrade hacluster to stable channel.\n" )
    fi
}

# default overlay setup
overlays+=(
    "etcd.yaml"
    "etcd-easyrsa.yaml"
    "easyrsa.yaml"
    "k8s-etcd.yaml"
)
if ! `has_opt '--master-ha*'`; then
    overlays+=( "k8s-lb.yaml"  )
fi
if ! `has_opt '--vault*'`; then
    overlays+=( "k8s-easyrsa.yaml" )
fi

trap_help $@
while (($# > 0))
do
    case "$1" in
        --k8s-channel)  #__OPT__
            # which Kubernetes channel to set on deployment
            parameters[__K8S_CHANNEL__]="$2"
            shift
            ;;
        --ceph)
            overlays+=( "ceph.yaml" )
            overlays+=( "k8s-ceph.yaml" )
            ;;
        --etcd-ha*)
            get_units $1 __NUM_ETCD_UNITS__ 1
            ;;
        --containerd)
            overlays+=( "k8s-containerd.yaml" )
            ;;
        --docker)
            if `has_opt '--containerd'`; then
                echo "ERROR: you can't use --docker and --containerd at the same time"
                exit 1
            fi
            overlays+=( "k8s-docker.yaml" )
            ;;
        --lb-ha-hacluster*|--lb-ha-keepalived*)
            if `has_opt '--master-ha*'`; then
                echo "ERROR: you can't do --master-ha and ${1%%:*} at the same time."
                exit 1
            fi
            get_units $1 __NUM_K8S_LB_UNITS__ 3
            if has_opt --lb-ha-keepalived*; then
                overlays+=( "k8s-lb-ha-keepalived.yaml" )
            else
                overlays+=( "k8s-lb-ha-hacluster.yaml" )
                check_hacluster_channel
            fi
            ;;
        --master-ha*)
            if `has_opt '--lb-ha*'`; then
                echo "ERROR: you can't do --lb-ha and --master-ha at the same time."
                exit 1
            fi
            get_units $1 __NUM_K8S_MASTER_UNITS__ 3
            overlays+=( "k8s-master-ha.yaml" )
            check_hacluster_channel
            ;;
        --vault)
            overlays+=( "vault.yaml" )
            overlays+=( "mysql.yaml" )
            overlays+=( "k8s-vault.yaml" )
            has_opt '--ceph' && overlays+=( "vault-ceph.yaml" )
            ;;
        --etcd-channel)
            parameters[__ETCD_SNAP_CHANNEL__]=$2
            shift
            ;;
        --vault-ha*)
            get_units $1 __NUM_VAULT_UNITS__ 3
            get_units $1 __NUM_ETCD_UNITS__ 3
            overlays+=( "vault-ha.yaml" )
            overlays+=( "vault-etcd.yaml" )
            set -- $@ --vault && cache $@
            ;;
        --num-workers)
            parameters[__NUM_K8S_WORKER_UNITS__]=$2
            shift
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

if ((${#msgs[@]})); then
  for m in "${msgs[@]}"; do
    echo -e "$m"
  done
read -p "Hit [ENTER] to continue"
fi

generate $f_rel_info
