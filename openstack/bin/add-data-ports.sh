#!/bin/bash -eu
application=${1:-nova-compute}  # note: can't be a subordinate
. ~/novarc
readarray -t instances<<<"`juju status $application --format=json| jq -r '.machines[].\"instance-id\"'`"
num_instances=${#instances[@]}
readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
[ -n "${ports[0]}" ] || ports=()
((${#ports[@]})) && delta=$((($num_instances - ${#ports[@]}) % $num_instances)) || delta=$num_instances
echo "Creating $delta new ports" 
for ((i=0;i<$delta;i++)); do
    openstack port create data-port --network ${OS_PROJECT_NAME}_admin_net
done
readarray -t ports<<<"`openstack port list| grep data-port| grep DOWN| awk '{print $2}'`"
i=0
for inst in "${instances[@]}"; do
    port=${ports[$((i++))]}
    echo "Adding port $port to server $inst"
    openstack server add port $inst $port
done
