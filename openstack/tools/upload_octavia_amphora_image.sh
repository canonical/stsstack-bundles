#!/bin/bash -eu

JUJU_VERSION=$(juju version | grep -oE '^[0-9]+' | head -1)

if [ -z "$JUJU_VERSION" ]; then
    echo "Error: Unable to determine Juju version."
    exit 1
fi

if [ "$JUJU_VERSION" -ge 3 ]; then
    if juju run octavia-diskimage-retrofit/leader retrofit-image --wait=10m; then
        echo "Success: Octavia amphora image upload completed."
    else
        echo "Error: Octavia amphora image upload failed."
        exit 1
    fi
else
    if juju run-action octavia-diskimage-retrofit/leader retrofit-image --wait=10m; then
        echo "Success: Octavia amphora image upload completed."
    else
        echo "Error: Octavia amphora image upload failed."
        exit 1
    fi
fi
