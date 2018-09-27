#!/bin/bash -eu
opts=(
--template openstack-extended.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
