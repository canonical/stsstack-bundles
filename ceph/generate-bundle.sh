#!/bin/bash -eu
opts=( $@ )
opts+=( --template ceph.yaml.template )
opts+=( --path $0 )
`dirname $0`/../generate-bundle.sh ${opts[@]}
