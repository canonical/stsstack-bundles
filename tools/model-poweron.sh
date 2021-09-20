#!/bin/bash -e
model=$1

(($#)) || { echo "You must provide a model name" && exit 1; }

source ~/novarc
echo "Fetching vms for model '${model}'..."
readarray -t vms<<<"`openstack server list -c ID -c Name -c Status -f value| egrep "juju-.+-${model}-[0-9]+"| grep SHUTOFF | awk '{print $1}'`"

echo -e "Starting ${#vms[@]} instances for model '${model}'"
openstack server start ${vms[@]}
echo "Done."
