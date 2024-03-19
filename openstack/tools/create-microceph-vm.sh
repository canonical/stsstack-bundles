#!/bin/bash

# https://github.com/canonical/microceph
# https://canonical-microceph.readthedocs-hosted.com/en/latest/
#
# Deploy using:
#
# juju add-model microceph
# juju deploy --constraints mem=16G --series jammy ubuntu microceph-vm
# juju scp openstack/tools/create-microceph-vm.sh microceph-vm/0:
# juju ssh microceph-vm/0 -- ./create-microceph-vm.sh
#
# After everything is deployed, ceph can be used via the ceph
# command, e.g.
#
# juju ssh microceph-vm/0 -- lxc exec microceph-1 ceph status

set -e -u

: ${VM_USER:=ubuntu}
: ${VM_NAME:=microceph}
: ${OSD_SIZE:=10}

init() {
    sudo usermod --append --groups lxd ubuntu
    lxd init --auto
    sudo snap install yq
}

as_root() {
    local VM_NAME=$1
    shift
    lxc exec ${VM_NAME} -- "$@"
}

as_user() {
    local VM_NAME=$1
    shift
    lxc exec ${VM_NAME} -- sudo --login --user ${VM_USER} "$@"
}

create_vm() {
    local vm_name=$1
    lxc launch --vm --config limits.memory=4GiB \
        --config limits.cpu=1 ubuntu:jammy ${vm_name}
}

vm_is_running() {
    local vm_name=$1
    if as_root ${vm_name} cloud-init status 2>&1 | grep --quiet done; then
        return 0
    fi
    return 1
}

print_help() {
    cat <<EOF
Usage:

$(basename $0) [options]

Options:

--help            This help
--name VM_NAME    Set VM_NAME
EOF
}

parse_commandline() {
    while (( $# > 0 )); do
        case $1 in
            --help)
                print_help
                exit
                ;;
            --name)
                shift
                VM_NAME=$1
                ;;
            *)
                echo "unknown argument $1"
                print_help
                exit 1
                ;;
        esac
        shift
    done
}

init
parse_commandline "$@"

# Create machines
for i in {1..3}; do
    echo "Creating ${VM_NAME}-${i}"
    create_vm ${VM_NAME}-${i}
done

# Wait for VMs to be fully up
echo -n "Waiting for VMs to become available"
for i in {1..3}; do
    while true; do
        if $(vm_is_running ${VM_NAME}-${i}); then
            echo -n "${i}"
            break
        else
            echo -n "."
            sleep 1
        fi
    done
done
echo "done"

# Add storage
for i in {1..3}; do
    if ! lxc storage volume show default osd-${i} 2>/dev/null; then
        echo "No storage pools found. Creating..."
        lxc storage volume create default osd-${i} \
            --type block size=${OSD_SIZE}GiB
    fi
    lxc config device add ${VM_NAME}-${i} osd-${i} disk \
        pool=default source=osd-${i}
done

# Wait for VMs
for i in {1..3}; do
    while ! as_user ${VM_NAME}-${i} snap list; do
        sleep 1
    done
done

# Prepare VMs
for i in {1..3}; do
    echo dm_crypt | as_root ${VM_NAME}-${i} tee --append /etc/modules
done

# Install Microceph
for i in {1..3}; do
    as_root ${VM_NAME}-${i} snap install microceph
done

# Prevent updates of snap
for i in {1..3}; do
    as_root ${VM_NAME}-${i} snap refresh --hold microceph
done

set -x

as_root ${VM_NAME}-1 microceph cluster bootstrap

# Get IP address of all cluster members
declare -a IPS=()
for i in {1..3}; do
    IPS+=($(lxc info ${VM_NAME}-${i} \
        | yq '.Resources.["Network usage"].[].["IP addresses"].inet' \
        | awk --field / '/global/{print $1}'))
done

for i in {1..3}; do
    for j in {1..3}; do
        printf "%s %s\n" ${IPS[j - 1]} ${VM_NAME}-${j} \
            | as_root ${VM_NAME}-${i} tee --append /etc/hosts
    done
done

TOKEN_2=$(as_root ${VM_NAME}-1 microceph cluster add ${VM_NAME}-2)
TOKEN_3=$(as_root ${VM_NAME}-1 microceph cluster add ${VM_NAME}-3)

as_root ${VM_NAME}-2 microceph cluster join ${TOKEN_2}
as_root ${VM_NAME}-3 microceph cluster join ${TOKEN_3}

as_root ${VM_NAME}-1 ceph status

# Add osds
for i in {1..3}; do
    as_root ${VM_NAME}-${i} microceph disk add /dev/sdb --wipe
done

sleep 2

as_root ${VM_NAME}-1 ceph status
as_root ${VM_NAME}-1 ceph osd status
as_root ${VM_NAME}-1 microceph enable rgw

as_root ${VM_NAME}-1 radosgw-admin user create \
    --uid=test --display-name=testuser
as_root ${VM_NAME}-1 radosgw-admin key create \
    --uid=test --key-type=s3 --access-key fooAccessKey \
    --secret-key fooSecretKey
