#!/bin/bash

function print_help {

    echo "This tool uploads converts and uploads the image specified."
    echo "Usage: ./tools/upload_image.sh <source> <image_name> <image_filename> <image_format>"
    echo ""
    echo "Parameter examples:"
    echo "    cloudimages xenial xenial-server-cloudimg-amd64-disk1.img qcow2"
    echo "    cloudimages bionic bionic-server-cloudimg-amd64.img raw"
    echo "    swift cirros cirros-0.4.0-x86_64-disk.img raw"
    echo "    swift cirros2 cirros-0.3.5-x86_64-disk.img qcow2"
    echo ""
    echo "WARNING: Downloaded/converted images will remain in your system."
    echo "         Delete them at ~/images if you need to reclaim disk space."
    echo ""
}

if (($# != 4)); then
    print_help
else
    set -x -e
    source ./profiles/common
    source novarc
    upload_image $1 $2 $3 $4
fi

