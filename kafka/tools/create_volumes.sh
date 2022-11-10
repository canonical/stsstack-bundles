#!/bin/bash -ux

machines=`juju status kafka --format=json | jq -r '.machines | to_entries[].value."instance-id"'`
num=`echo "$machines" | wc -l`

volumeIds=()
for i in $(seq 1 $((num*2))); do
	if [ "`openstack volume list --name kafka-vol-$i -c Status -f value`" != "available" ]; then
		volumeIds+=(`openstack volume create kafka-vol-$i --size 1 -c id -f value`)
	else
		volumeIds+=(`openstack volume list --name kafka-vol-$i -c ID -f value`)
	fi
done

i=0
for machine in $machines; do
	openstack server add volume $machine ${volumeIds[$((i++))]}
	openstack server add volume $machine ${volumeIds[$((i++))]}
done
