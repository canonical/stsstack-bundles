#!/bin/bash -eu
#
# Create a new port (unless one already exists) and add to each
# application unit host such each unit has one (and only one)
# extra port.
#
application=${1:-neutron-openvswitch}
declare -A requires=()

. ~/novarc
readarray -t instances<<<"`juju status $application --format=json| jq -r '.machines[].\"instance-id\"'`"

require_count=0
echo "Checking $application unit instances: ${instances[@]}"
for inst in "${instances[@]}"; do
    num_ports="`openstack port list --server $inst| grep ACTIVE| wc -l`"
    if ((num_ports>1)); then
        requires[$inst]=false
    else
        requires[$inst]=true
        ((require_count+=1))
    fi
done

if ((require_count)); then
    # Get extant free ports
    readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
    [ -n "${ports[0]}" ] || ports=()
    num_ports=${#ports[@]}
    if ((num_ports >= require_count)); then
        delta=0
    elif ((num_ports > 0)); then
        delta=$((require_count - num_ports))
    else
        delta=$require_count
    fi
    if ((delta)); then
        echo "Creating $delta new ports"
        for ((i=0;i<$delta;i++)); do
            openstack port create data-port --network ${OS_PROJECT_NAME}_admin_net
        done
    fi

    declare -a mac_addrs=()
    readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
    i=0
    for inst in "${instances[@]}"; do
        ${requires[$inst]} || continue
        port=${ports[$((i++))]}
        echo "Adding port $port to server $inst"
        openstack server add port $inst $port
        mac_addrs+=( "br-data:`openstack port show -c mac_address -f value $port`" )
    done
    echo "Updating neutron-openvswitch data-port"
    cfg="`juju config neutron-openvswitch data-port`"
    for m in "${mac_addrs[@]}"; do
        echo "$cfg"| grep -q "$m" && continue 
        cfg+=" $m"
    done
    juju config neutron-openvswitch data-port="$cfg"
else
    echo "All instances have > 1 port already - nothing to do"
fi

echo "Done."
