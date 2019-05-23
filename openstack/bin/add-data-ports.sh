#!/bin/bash -eu
#
# Create a new port (unless one already exists) and add to each
# nova-compute unit host such each unit has one (and only one)
# extra port.
#
application=${1:-nova-compute}  # note: can't be a subordinate
. ~/novarc
readarray -t instances<<<"`juju status $application --format=json| jq -r '.machines[].\"instance-id\"'`"

declare -A requires=()
require_count=0
echo "Checking nova-compute units: ${instances[@]}"
for inst in "${instances[@]}"; do
    num_ports="`openstack port list --server $inst| grep ACTIVE| wc -l`"
    if ((num_ports>1)); then
        requires[$inst]=false
    else
        requires[$inst]=true
        ((require_count+=1))
    fi
done

if ((require_count>0)); then
    # Get extant free ports
    readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
    [ -n "${ports[0]}" ] || ports=()
    if ((${#ports[@]})); then
        delta=$((($require_count - ${#ports[@]}) % $require_count))
    else
        delta=$require_count
    fi

    echo "Creating $delta new ports" 
    for ((i=0;i<$delta;i++)); do
        openstack port create data-port --network ${OS_PROJECT_NAME}_admin_net
    done

    readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
    i=0
    for inst in "${instances[@]}"; do
        ${requires[$inst]} || continue
        port=${ports[$((i++))]}
        echo "Adding port $port to server $inst"
        openstack server add port $inst $port
    done
else
    echo "All instances have > 1 port already - nothing to do"
fi

echo "Done."
