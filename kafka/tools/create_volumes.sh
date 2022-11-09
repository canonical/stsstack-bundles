#!/bin/bash -ux

model=`juju show-model --format=json| jq -r '.| keys[]'`
machines=`juju status $model --format=json | jq -r '.machines | to_entries[].value."instance-id"'`
num=`echo "$machines" | wc -l`

for i in $(seq 1 $((num*2))); do
	if [ "`openstack volume list --name kafka-vol-$i -c Status -f value`" != "available" ]; then
		openstack volume create kafka-vol-$i --size 1
	fi
done

i=1
for machine in $machines; do
	openstack server add volume $machine kafka-vol-$((i++))
	openstack server add volume $machine kafka-vol-$((i++))
done
