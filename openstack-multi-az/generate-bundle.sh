#!/bin/bash -eu
opts=( $@ )
opts+=( --template openstack-multi-az.yaml.template )
opts+=( --path $0 )
`dirname $0`/../generate-bundle.sh ${opts[@]}
