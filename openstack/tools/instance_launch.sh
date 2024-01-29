#!/bin/bash

set -e -u

source "$(realpath $(dirname $0))/../novarc"

# Launch N quantity of XYZ instances
#
# Presumes glance images exist and have been imported using the accompanying
# configure script.

declare -a DEFAULT_NETS=(private)
declare -a net_names=()
instance_qty=0
image_name=
server_name=

while (( $# > 0 )); do
    case $1 in
        -h|--help)
            cat <<EOF
Usage:

$(basename $0) [--num-instances] N [--image] IMAGE [--name NAME] [--network NETWORK]

Example:

$(basename $0) 10 xenial-ppc64el

Note, cirros images will use the m1.cirros flavor. All others will use the
m1.small flavor.

Options:

--num-instances N   Launch N instances
--image IMAGE       Use IMAGE
--name NAME         The server name (defaults to IMAGE-DATE)
--network NETWORK[,NETWORK[,NETWORK[...]]]
                    Connect instances to NETWORK(s) (defaults to ${DEFAULT_NETS[@]})
EOF
            exit
            ;;
        --num-instances)
            shift
            instance_qty=$(($1))
            ;;
        --image)
            shift
            image_name=$1
            ;;
        --network)
            shift
            old_IFS=${IFS}
            IFS=','
            read -r -a new_net_names <<< "$1"
            IFS=${old_IFS}
            net_names+=( "${new_net_names[@]}" )
            ;;
        --name)
            shift
            server_name=$1
            ;;
        -*)
            echo "Unknown argument '$1'"
            exit 1
            ;;
        *)
            if (( instance_qty == 0 )); then
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    instance_qty=$(($1))
                else
                    echo "Unknown argument '$1'"
                    exit 1
                fi
                if (( $1 <= 0 )); then
                    echo "Number of instances has to be greater than 0"
                    exit 1
                fi
                instance_qty=$(($1))
            elif [[ -z ${image_name} ]]; then
                image_name=$1
            else
                echo "Unknown argument '$1'"
                exit 1
            fi
            ;;
    esac
    shift
done

if (( instance_qty <= 0 )); then
    echo "Missing number of instances"
    exit 1
fi

if [[ -z ${image_name} ]]; then
    echo "Missing image name"
    exit 1
fi

if (( ${#net_names[@]} == 0 )); then
    net_names=( "${DEFAULT_NETS[@]}" )
fi

set -x

# Create Nova keypair. Don't clobber existing keyfile in case it is being used
# for multiple models at once.
prvkey=~/testkey.priv
pubkey=~/testkey.pub
if ! openstack keypair show testkey; then
    if [ -r $prvkey ] && [ -r $pubkey ]; then
        openstack keypair create testkey --public-key $pubkey
    else
        openstack keypair create testkey > $prvkey
        openstack keypair show testkey --public-key > $pubkey
    fi
    chmod 600 $prvkey
fi

# Grab private network ID
net_ids=()
for net_name in ${net_names[@]}; do
    net_ids+=("--nic net-id=$(openstack network show --format value --column id ${net_name})")
done

# Determining flavor to use
if [[ "${image_name}" =~ cirros ]]; then
  flavor="m1.cirros"
else
  flavor="m1.small"
fi

# Create instances
if [[ -z ${server_name} ]]; then
    server_name="${image_name}-$(date +'%H%M%S')"
fi
openstack server create --wait \
    --image $image_name \
    --flavor $flavor \
    --key-name testkey \
    ${net_ids[@]} \
    --min $instance_qty \
    --max $instance_qty \
    $server_name

echo 'Hint: use ssh -i ~/testkey.priv ubuntu@<ip> to access new instances (may also need a floating IP, see ./tools/float_all.sh).'
