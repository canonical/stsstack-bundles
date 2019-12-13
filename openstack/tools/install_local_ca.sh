#!/bin/bash -eux
local_ca_crt_path=${1:-ssl/openstack/results/cacert.pem}
use_vault=${2:-false}

ftmp=`mktemp`

cleanup () { rm -f $ftmp; }
trap cleanup EXIT INT

if $use_vault || ! [ -e "$local_ca_crt_path" ]; then
    echo "Fetching CA cert from vault"
    juju run-action --format=json vault/leader get-root-ca --wait | jq -r .[].results.output > $ftmp
    local_ca_crt_path=$ftmp
fi

echo "INFO: installing stsstack-bundles openstack CA at /usr/local/share/ca-certificates/cacert.crt"
sudo cp ${local_ca_crt_path} /usr/local/share/ca-certificates/cacert.crt
sudo chmod 644 /usr/local/share/ca-certificates/cacert.crt
sudo update-ca-certificates --fresh
