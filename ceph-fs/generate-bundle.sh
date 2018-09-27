#!/bin/bash -eu
opts=(
--template ceph-fs.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
