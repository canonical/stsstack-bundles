#!/bin/bash -eu

source $(realpath $(dirname $0))/../novarc

IMAGE_ID=$(openstack image list --name jammy --format value --column ID)

if [[ -n ${IMAGE_ID} ]]; then
    juju run octavia-diskimage-retrofit/0 retrofit-image source-image=${IMAGE_ID}
else
    echo "Could not find a suitable image. Please upload a jammy image"
    echo "to glance (e.g. by running the configure script) before"
    echo "uploading an Octavia image."
    exit 1
fi
