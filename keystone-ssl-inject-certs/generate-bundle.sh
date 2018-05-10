#!/bin/bash -eu
opts=( $@ )
opts+=( --template keystone-ssl-inject-certs.yaml.template )
opts+=( --path $0 )
`dirname $0`/../generate-bundle.sh ${opts[@]}
