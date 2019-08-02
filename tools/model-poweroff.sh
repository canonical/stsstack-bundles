#!/bin/bash -e
model=$1

(($#)) || { echo "You must provide a model name" && exit 1; }

echo -e "Power off all instances for model '$model'\nContinue? [y/N] "
read answer
[ "${answer,,}" = "y" ] || { echo "aborted"; exit 0; }

source ~/novarc
echo "Fetching vms for model..."
readarray -t vms<<<"`openstack server list -c ID -c Name -f value| egrep "juju-.+-${model}-[0-9]+"| awk '{print $1}'`"
echo "Powering off ${#vms[@]} vms"
openstack server stop ${vms[@]}
echo "Done."
