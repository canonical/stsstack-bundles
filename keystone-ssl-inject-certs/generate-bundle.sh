#!/bin/bash -eu
opts=(
--template keystone-ssl-inject-certs.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
