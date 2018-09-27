#!/bin/bash -eu
opts=(
--template openstack-multi-az.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
