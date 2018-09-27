#!/bin/bash -eu
opts=(
--template openstack-nova-network.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
