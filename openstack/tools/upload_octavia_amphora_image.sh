#!/bin/bash -eu

JUJU_VERSION=$(juju version | grep -oE '^[0-9]+' | head -1)

if [ -z "$JUJU_VERSION" ]; then
    echo "Error: Unable to determine Juju version."
    exit 1
fi

run="run"
if [ "$JUJU_VERSION" -lt 3 ]; then
    run="run-action"
fi

if juju ${run} octavia-diskimage-retrofit/leader retrofit-image --wait=15m; then
    echo "Success: Octavia amphora image upload completed."
else
    echo "Error: Octavia amphora image upload failed."
    exit 1
fi
