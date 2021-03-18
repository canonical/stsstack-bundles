#!/bin/bash -eu
#
# Create a new port (unless one already exists) and add to each
# application unit host such each unit has one (and only one)
# extra port.
#
application=${1:-""}
(($#>1)) && network="$2" || network=""
(($#>2)) && bridge="$3" || bridge="br-data"

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
[ -n "$network" ] || network="${OS_PROJECT_NAME}_admin_net"

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
    num_ports="`openstack port list --network $network --server $inst| grep data-port| wc -l`"
    if ((num_ports)); then
        requires[$inst]=false
    else
        requires[$inst]=true
        ((require_count+=1))
    fi
done

declare -a ports_filtered=()
if ((require_count)); then
    # Get extant free ports
    readarray -t ports<<<"`openstack port list --network $network| grep " data-port "| grep DOWN| awk '{print $2}'`"
    [ -n "${ports[0]}" ] || ports=()
    for port in ${ports[@]}; do
        device=`openstack port show $port  -c device_id -f value`
        [[ -z $device ]] || continue
        ports_filtered+=( $port )
    done

    num_ports=${#ports_filtered[@]}
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
            id=`openstack port create data-port --network $network --no-fixed-ip -c id -f value`
            ports_filtered+=( $id )
        done
    fi

    declare -a mac_addrs=()
    i=0
    for inst in "${instances[@]}"; do
        ${requires[$inst]} || continue
        port=${ports_filtered[$((i++))]}
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
        cfg+="$bridge:$mac"
    done
    echo "Setting $application ${optname}='$cfg'"
    juju config $application ${optname}="$cfg"
else
    echo "All instances have at least 1 port on network $network (bridge=$bridge) - nothing to do"
fi

echo "Done."
