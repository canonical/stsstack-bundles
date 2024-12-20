#!/bin/bash

set -e -u

declare amphora_series=jammy

while (( $# > 0 )); do
    case $1 in
        -h|--help)
            cat <<EOF
Usage:

-h | --help         This help
--series SERIES     The series (also the image name) to use as the amphora base
EOF
            exit
            ;;
        --series)
            shift
            amphora_series=$1
            ;;
        *)
            echo "unknown option"
            exit 1
            ;;
    esac
    shift
done

basedir=$(realpath $(dirname $0))
source ${basedir}/../novarc

ID=$(openstack image show --format value --column id ${amphora_series})

TASK=$(juju run octavia-diskimage-retrofit/0 retrofit-image source-image=${ID} --background 2>&1 | grep show-task | sed --regexp-extended 's/^.*task ([0-9]+).*/\1/')

echo -n "Running retrofit"
while [[ $(juju show-task ${TASK}) =~ running ]]; do
    echo -n .
    sleep 5
done
echo

ID=$(openstack image list --format json | jq --raw-output '.[] | select(.Name | match("amphora")) | .ID')

openstack image set --tag octavia-amphora ${ID}
