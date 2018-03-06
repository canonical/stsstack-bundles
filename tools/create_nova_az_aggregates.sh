#!/bin/bash -eu
for az in az1 az2; do
    readarray ids<<<"`juju status nova-compute-$az --format=yaml| grep instance-id| awk '{print $2}'`"
    machines=()
    for id in ${ids[@]}; do machines+=( `openstack server show $id| grep " name "| awk '{print $4}'` ); done
    nova aggregate-details ${az^^} &>/dev/null || nova aggregate-create ${az^^} $az;    
    for m in ${machines[@]}; do
        openstack aggregate show ${az^^}| grep -q $m || openstack aggregate add host ${az^^} $m
    done
done
