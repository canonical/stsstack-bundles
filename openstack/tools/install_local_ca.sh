#!/bin/bash -eu

validate_or_remove_ca() {
    if [ -f $1 ]; then
        if grep -Fxq -- "-----BEGIN CERTIFICATE-----" $1; then
            return 0
        else
            rm $1
        fi
    fi
    return 1
}

if ((`juju status --format=json| jq -r '.applications[]| select(."charm-name"=="vault")'| wc -l`)); then
    model_uuid=`juju show-model --format=json| jq -r '.[]."model-uuid"'`
    model_ca_cert_path=/tmp/stsstack-bundles.ssl.$model_uuid

    if ! validate_or_remove_ca ${model_ca_cert_path}; then
      echo "Fetching CA cert from vault" 1>&2
      juju run-action --format=json vault/leader get-root-ca --wait | jq -r .[].results.output > $model_ca_cert_path
      if ! validate_or_remove_ca $model_ca_cert_path; then
        echo "Didn't get a certificate from vault, check it's status and if necessary use ./tools/vault-unseal-and-authorise.sh" 1>&2
        exit 1
      fi
    fi
elif [ -n "`juju config keystone ssl_cert`" ]; then
    MOD_DIR=$(dirname $0)/..
    readarray -t certs<<<"`find $MOD_DIR/ssl/ -name cacert.pem`"
    if ((${#certs[@]})) && [ -n "${certs[0]}" ]; then
        if ((${#certs[@]}>1)); then
            echo "" 1>&2
            for ((i=0;i<${#certs[@]};i++)); do
                echo "[$i] ${certs[$i]}" 1>&2
            done
            read -p "CA cert to use [0-$((i-1))]: " cert_idx
        else
            cert_idx=0
        fi
        model_ca_cert_path=${certs[$cert_idx]}
    else
        echo "INFO: no cacerts found at $MOD_DIR/ssl/ - not installing" 1>&2
    fi
fi

if [ -n "$model_ca_cert_path" ] && [ -f "$model_ca_cert_path" ]; then
    if [ ! -f /usr/local/share/ca-certificates/cacert.crt ] || [ $(md5sum $model_ca_cert_path | awk '{print $1}') != $(md5sum /usr/local/share/ca-certificates/cacert.crt | awk '{print $1}') ]; then
        echo "INFO: installing stsstack-bundles openstack CA from /usr/local/share/ca-certificates/cacert.crt" 1>&2
        sudo cp ${model_ca_cert_path} /usr/local/share/ca-certificates/cacert.crt
        sudo chmod 644 /usr/local/share/ca-certificates/cacert.crt
        sudo update-ca-certificates --fresh 1>/dev/null
    fi
fi
