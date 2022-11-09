#!/bin/bash -e
model=$1

if (($# == 0)); then
    echo "You must provide a model name"
    exit 1
fi

source ~/novarc
echo "Fetching vms for model '${model}'..."
readarray -t vms <<<"`openstack server list -c ID -c Name -f value| egrep "juju-.+-${model}-[0-9]+"| awk '{print $1}'`"

echo -en "Power off ${#vms[@]} instances for model '${model}'\nContinue? [y/N]"
read answer
[ "${answer,,}" = "y" ] || { echo "aborted"; exit 0; }

echo "Stopping vms: ${vms[*]}"
openstack server stop "${vms[@]}"
echo "Done."
