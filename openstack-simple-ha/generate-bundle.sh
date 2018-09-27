#!/bin/bash -eu
opts=(
--template openstack-simple-ha.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
