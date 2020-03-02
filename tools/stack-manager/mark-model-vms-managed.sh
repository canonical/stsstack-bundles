#!/bin/bash -u
. `dirname $0`/common.sh
model=${1:-""}

[ -n "$model" ] || { echo "ERROR: model name not provided"; exit 1; }

openstack object save stack-manager-${OS_PROJECT_NAME} --file $STAGING_DIR/managed_vms.json managed_vms.json
echo "Marking vms for model $model as managed=true"
jq "(.catalog[].servers)|=(map((if .name|test(\"^juju-[a-z0-9]+-${model}-[0-9]+\") then .managed=\"true\" else . end)))" $STAGING_DIR/managed_vms.json > $STAGING_DIR/managed_vms.json.updated
diff $STAGING_DIR/managed_vms.json $STAGING_DIR/managed_vms.json.updated &>/dev/null
if (($?>0)); then
    openstack object create stack-manager-${OS_PROJECT_NAME} --name managed_vms.json $STAGING_DIR/managed_vms.json.updated
else
    echo "no changes applied"
fi
echo "Done."
