#!/bin/bash -eu
opts=( $@ )
opts+=( --template keystone-ssl.yaml.template )
opts+=( --path $0 )
`dirname $0`/../generate-bundle.sh ${opts[@]}
