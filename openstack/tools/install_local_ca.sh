#!/bin/bash -eux
model_ca_cert_path=${1:-ssl/openstack/results/cacert.pem}

if ((`juju status --format=json| jq -r '.applications[]| select(."charm-name"=="vault")'| wc -l`)); then
    model_uuid=`juju show-model --format=json| jq -r '.[]."model-uuid"'`
    model_ca_cert_path=`find /tmp -name \*.stsstack-bundles.ssl.$model_uuid 2>/dev/null` || true
    if [[ -z "$model_ca_cert_path" || "$(cat $model_ca_cert_path)" = "None" ]]; then
        model_ca_cert_path=`mktemp --suffix=.stsstack-bundles.ssl.$model_uuid`
        echo "Fetching CA cert from vault"
        juju run-action --format=json vault/leader get-root-ca --wait | jq -r .[].results.output > $model_ca_cert_path
    fi
fi

echo "INFO: installing stsstack-bundles openstack CA at /usr/local/share/ca-certificates/cacert.crt"
sudo cp ${model_ca_cert_path} /usr/local/share/ca-certificates/cacert.crt
sudo chmod 644 /usr/local/share/ca-certificates/cacert.crt
sudo update-ca-certificates --fresh
