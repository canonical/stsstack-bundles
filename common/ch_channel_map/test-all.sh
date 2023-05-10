#!/bin/sh

# Helps you compare the results of any changes to ch_channel_map
#
# Usage:
#   mkdir before after
#   ./test-all.sh before
#   # make your changes
#   ./test-all.sh after
#   diff -Nru before after

if [ $# -eq 1 ] && [ -d $1 ]; then
  output_prefix=$1/
else
  output_prefix=
fi

series=bionic
for release in queens rocky stein train ussuri; do
  ./test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done

series=focal
for release in ussuri victoria wallaby xena yoga; do
  ./test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done

series=jammy
for release in yoga zed antelope; do
  ./test-channel-map.sh $series $release > ${output_prefix}$series-$release.txt
done
