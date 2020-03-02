#!/bin/bash -u
. `dirname $0`/common.sh
openstack object save stack-manager-${OS_PROJECT_NAME} --file $STAGING_DIR/managed_vms.json managed_vms.json
echo "UUID NAME MANAGED EXPIRES" > $STAGING_DIR/out
jq -r '.catalog[].servers[]| [.id,.name,.managed,.date_expires]| @tsv' $STAGING_DIR/managed_vms.json >> $STAGING_DIR/out
column -t $STAGING_DIR/out
