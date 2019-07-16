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
--internal-generator-path `dirname $0`
)
if ! `has_opt '--use-stable-charms' ${CACHED_STDIN[@]:-""}`; then
    opts+=( "--charm-channel edge" )
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


# default for current stable is to use containerd
# See https://ubuntu.com/kubernetes/docs/container-runtime
if ! `has_opt '--k8s-channel' ${CACHED_STDIN[@]}` && \
   ! `has_opt '--docker' ${CACHED_STDIN[@]}`; then
    set -- $@ --containerd
fi

trap_help ${CACHED_STDIN[@]:-""}
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
            if `has_opt '--containerd' ${CACHED_STDIN[@]}`; then
                echo "ERROR: you can't use --docker and --containerd at the same time"
                exit 1
            fi
            overlays+=( "k8s-docker.yaml" )
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
