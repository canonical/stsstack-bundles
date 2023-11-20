#!/bin/bash

# Helps you compare the results of any changes to ch_channel_map
#
# Usage:
#   mkdir before after
#   ./test-all.sh before
#   # make your changes
#   ./test-all.sh after
#   diff -Nru before after

basedir=$(realpath $(dirname $0))

if [[ $# -eq 1 ]]; then
    mkdir --parents $1
    output_prefix=$1/
else
    output_prefix=
fi

series=bionic
for release in queens rocky stein train ussuri; do
    ${basedir}/test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done

series=focal
for release in ussuri victoria wallaby xena yoga; do
    ${basedir}/test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done

series=jammy
for release in yoga zed antelope bobcat; do
    ${basedir}/test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done
