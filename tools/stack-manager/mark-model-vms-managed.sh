#!/bin/bash -u
model=${1:-""}

[ -n "$model" ] || { echo "ERROR: model name not provided"; exit 1; }

d_out=`mktemp -d`
clean ()
{
    rm -rf $d_out
}
trap clean INT EXIT

openstack object save stack-manager-${OS_PROJECT_NAME} --file $d_out/managed_vms.json managed_vms.json
echo "Marking vms for model $model as managed=true"
jq "select(.catalog[].servers[].name | match(\"^juju-[a-z0-9]+-${model}-[0-9]+\")) | .catalog[].servers[].managed=\"true\"" $d_out/managed_vms.json > $d_out/managed_vms.json.updated
diff $d_out/managed_vms.json $d_out/managed_vms.json.updated &>/dev/null
if (($?>0)); then
    openstack object create stack-manager-${OS_PROJECT_NAME} --name managed_vms.json $d_out/managed_vms.json.updated
else
    echo "no changes applied"
fi
echo "Done."
