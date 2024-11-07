#!/bin/bash -eu

# This file assists the main charmed_functest_runner script but can also be invoked separately
# by passing the target (jammy-antelope, focal-yoga, etc) to run and a sleep timer between the
# configure and test run. If run manually, the .charm file must exist in the source code folder
# and the environment variables need to have been exported prior to invoking this script.
#
# What this script does is run the functions functest-deploy, functest-configure and
# functest-test separately one after the other, instead of the entire suite run in the
# same command that the command functest-target does.
#
# The main advantages of this is that it is easier for debugging, and it can also help
# when there are race conditions running the charm test (by using the sleep parameter).
#
# Ideally, all those issues should be worked out in zaza, but having this alternative
# makes it easier for debugging, testing, and validating the race condition.

TARGET=$1
SLEEP=$2
INIT_NOOP_TARGET=$3

if [[ $INIT_NOOP_TARGET = true ]]; then
    tox -re func-noop
fi

juju add-model test-$TARGET --no-switch

# Those below are the parameters that are used when functest-target creates a model named "zaza-<hash>"

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

