#!/bin/bash

set -e -u

basedir=$(realpath $(dirname $0))
source ${basedir}/../novarc

set -x

ID=$(openstack image show --format value --column id jammy)

TASK=$(juju run octavia-diskimage-retrofit/0 retrofit-image source-image=${ID} --background 2>&1 | grep show-task | sed --regexp-extended 's/^.*task ([0-9]+).*/\1/')

echo -n "Running retrofit"
while [[ $(juju show-task ${TASK}) =~ running ]]; do
    echo -n .
    sleep 5
done
echo

ID=$(openstack image list --format json | jq --raw-output '.[] | select(.Name | match("amphora")) | .ID')

openstack image set --tag octavia-amphora ${ID}
