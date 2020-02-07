#!/bin/bash -eu
#
# Create a new port (unless one already exists) and add to each
# application unit host such each unit has one (and only one)
# extra port.
#
application=${1:-""}
declare -A requires=()

# if no app name provided, assume neutron-openvswitch then ovn-chassis
if [ -z "$application" ]; then
    for app in neutron-openvswitch ovn-chassis; do
        count=`juju status --format=json| jq -r ".applications[]| select(.\"charm-name\"==\"$app\")"| wc -l`   
        ((count==0)) && continue    
        application=$app
        break
    done
fi

echo "Managing ports for $application units"

. ~/novarc
readarray -t instances<<<"`juju status $application --format=json| jq -r '.machines[].\"instance-id\"'`"

if [ "$application" = "ovn-chassis" ] && \
        ((`juju status ovn-chassis --format=json 2>/dev/null| jq '.machines| length'`)); then
    optname="bridge-interface-mappings"
else
    optname="data-port"
fi

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
            openstack port create data-port --network ${OS_PROJECT_NAME}_admin_net --no-fixed-ip
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
        mac_addrs+=( "`openstack port show -c mac_address -f value $port`" )
    done
    echo "Updating $application $optname"
    cfg="`juju config $application $optname`"
    [ -n "$cfg" ] && first=false || first=true
    for mac in "${mac_addrs[@]}"; do
        echo "$cfg"| grep -q "$mac" && continue
        ! $first && cfg+=" " || first=false
        cfg+="br-data:$mac"
    done
    echo "Setting $application ${optname}='$cfg'"
    juju config $application ${optname}="$cfg"
else
    echo "All instances have > 1 port already - nothing to do"
fi

echo "Done."
