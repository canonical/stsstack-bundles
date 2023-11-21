#!/bin/bash -ux

. $(dirname $0)/../common/juju_helpers

which vault > /dev/null || sudo snap install vault
which jq > /dev/null || sudo apt install -y jq

model=`juju show-model --format=json| jq -r '.| keys[]'`
model_uuid=`juju show-model --format=json| jq -r '.[]."model-uuid"'`
unseal_output=~/unseal_output.$model

ftmp=`mktemp`
juju status --format=json vault > $ftmp
readarray -t addrs<<<"`jq -r '.applications[].units[]?."public-address"' $ftmp 2>/dev/null`"
leader="`jq -r '.applications[] | select(."charm-name"=="vault") | .units | to_entries[] | select(.value.leader==true) | .key' $ftmp 2>/dev/null`"
leader_addr="`jq -r '.applications[]| select(."charm-name"=="vault") |.units | to_entries[] | select(.value.leader==true) | .value."public-address"' $ftmp 2>/dev/null`"
rm $ftmp

init=true
if [ -r "$unseal_output" ] && [ "`head -n 1 $unseal_output`" = "$model_uuid" ] ; then
    read -p "Unseal info file $unseal_output already exists - overwrite? [y/N]" answer
    if [ -n "$answer" ] && [ "${answer,,}" = "y" ]; then
        init=true
    else
        init=false
    fi
fi
if $init; then
    export VAULT_ADDR="http://$leader_addr:8200"
    echo "$model_uuid" > $unseal_output
    vault operator init -key-shares=5 -key-threshold=3 &>> $unseal_output
fi

for addr in ${addrs[@]}; do
    export VAULT_ADDR="http://$addr:8200"
    key1=`sed -r 's/Unseal Key 1: (.+)/\1/g;t;d' $unseal_output`
    key2=`sed -r 's/Unseal Key 2: (.+)/\1/g;t;d' $unseal_output`
    key3=`sed -r 's/Unseal Key 3: (.+)/\1/g;t;d' $unseal_output`
    token=`sed -r 's/Initial Root Token: (.+)/\1/g;t;d' $unseal_output`
    vault operator unseal $key1
    vault operator unseal $key2
    vault operator unseal $key3
    export VAULT_TOKEN=$token
    vault token create -ttl=10m
done

juju $JUJU_RUN_CMD $leader authorize-charm token=$token
