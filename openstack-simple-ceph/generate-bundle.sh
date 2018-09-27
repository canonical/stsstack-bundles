#!/bin/bash -eu
opts=(
--template openstack-simple-ceph.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
