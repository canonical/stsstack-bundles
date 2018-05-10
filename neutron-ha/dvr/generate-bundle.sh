#!/bin/bash -eu
opts=( $@ )
opts+=( --template dvr.yaml.template )
opts+=( --path $0 )
`dirname $0`/../../generate-bundle.sh ${opts[@]}
