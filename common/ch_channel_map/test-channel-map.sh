#!/bin/bash

set -e -u

series=$1
release=$2

declare -A CHARM_CHANNEL

# This variable is set to avoid an "undefined" error but otherwise not used
ceph_release=octopus

SCRIPT_DIR=$(dirname $0)

. ${SCRIPT_DIR}/../charm_lists
. ${SCRIPT_DIR}/${series}
if [[ -f ${SCRIPT_DIR}/${series}-${release} ]]; then
    . ${SCRIPT_DIR}/${series}-${release}
fi
. ${SCRIPT_DIR}/any_series

output=$(mktemp)

for charm in \
    hacluster \
    mysql-{router,innodb-cluster} \
    ovn-{central,chassis,dedicated-chassis} \
    percona-cluster \
    rabbitmq-server \
    vault \
    barbican-vault \
    nova-compute \
    ceph-osd
do
    if [[ -v CHARM_CHANNEL[${charm}] ]]; then
        echo "${charm} ${CHARM_CHANNEL[${charm}]}" >> ${output}
    else
        echo "${charm} unset" >> ${output}
    fi
done
cat ${output} | column -t
rm ${output}
