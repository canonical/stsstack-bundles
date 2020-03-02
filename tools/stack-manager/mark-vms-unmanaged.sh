#!/bin/bash -u
. `dirname $0`/common.sh
vms=( $@ )

(("${#vms[@]}")) || { echo "ERROR: no vms provided"; exit 1; }

openstack object save stack-manager-${OS_PROJECT_NAME} --file $STAGING_DIR/managed_vms.json managed_vms.json
echo "Marking ${#vms[@]} vms as managed=false"
cp $STAGING_DIR/managed_vms.json $STAGING_DIR/managed_vms.json.updated
for vm in ${vms[@]}; do
    jq "(.catalog[].servers)|=(map((if .id|test(\"$vm\") then .managed=\"false\" else . end)))" $STAGING_DIR/managed_vms.json.updated > $STAGING_DIR/managed_vms.json.updated.tmp
    cp $STAGING_DIR/managed_vms.json.updated.tmp $STAGING_DIR/managed_vms.json.updated
done
diff $STAGING_DIR/managed_vms.json $STAGING_DIR/managed_vms.json.updated &>/dev/null
if (($?>0)); then
    openstack object create stack-manager-${OS_PROJECT_NAME} --name managed_vms.json $STAGING_DIR/managed_vms.json.updated
else
    echo "no changes applied"
fi
echo "Done."
