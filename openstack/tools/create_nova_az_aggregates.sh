#!/bin/bash -eu
for az in az1 az2; do
    readarray ids<<<"`juju status nova-compute-$az --format=yaml| grep instance-id| awk '{print $2}'`"
    machines=()
    for id in ${ids[@]}; do machines+=( `source ~/novarc; openstack server show $id| grep " name "| awk '{print $4}'` ); done
    echo "Creating aggregate ${az^^}"
    openstack aggregate show ${az^^} &>/dev/null || openstack aggregate create --zone $az ${az^^};
    for m in ${machines[@]}; do
        echo "Adding host $m to aggregate ${az^^}"
        openstack aggregate show ${az^^}| grep -q $m || openstack aggregate add host ${az^^} $m
    done
done
