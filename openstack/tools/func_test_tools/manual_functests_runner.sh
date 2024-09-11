#!/bin/bash -eu

TARGET=$1
SLEEP=$2

if [[ ! -d ./.tox/func-noop ]]; then
    tox -e func-noop
fi

juju add-model test-$TARGET --no-switch

juju model-config -m test-$TARGET test-mode=true transmit-vendor-metrics=false enable-os-upgrade=false default-series=jammy automatically-retry-hooks=false

source ./.tox/func-noop/bin/activate

functest-deploy -b tests/bundles/$TARGET.yaml -m test-$TARGET

juju status -m test-$TARGET

functest-configure -m test-$TARGET

juju status -m test-$TARGET

echo "Sleeping for $SLEEP seconds"

sleep $SLEEP

echo "Woke up"

juju status -m test-$TARGET

functest-test -m test-$TARGET

juju status -m test-$TARGET

echo "Finished $TARGET"

