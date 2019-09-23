#!/bin/bash -eux
# Upload amphora image from stsstack swift to overcloud glance.
source ~/novarc

tmp=`mktemp`
source ~/novarc
swift list images > $tmp
ts="`sed -r 's/.+-([[:digit:]]+)\.[[:alnum:]]+$/\1/g;t;d' $tmp| sort -h| tail -n 1`"
img="`grep $ts $tmp| tail -n 1`"
rm $tmp

export SWIFT_IP="10.230.19.58"
. ./profiles/common
source novarc
upload_image swift octavia-amphora $img
openstack image set --tag octavia-amphora octavia-amphora
