#!/bin/bash
# Delete leaked gateway ext-ports on the undercloud before a func test.
#
# Usage: clean_orphan_dataports.sh [OPENRC]   (default: ~/novarc)
set -eu

OPENRC=${1:-$HOME/novarc}
if [[ ! -r $OPENRC ]]; then
    echo "WARNING: no undercloud openrc ($OPENRC) - skipping ext-port cleanup" >&2
    exit 0
fi
source "$OPENRC"
if ! command -v openstack &>/dev/null; then
    echo "WARNING: no openstack CLI - skipping ext-port cleanup" >&2
    exit 0
fi

readarray -t ports < <(openstack port list -f value -c ID -c Name)
deleted=0
for line in "${ports[@]}"; do
    read -r pid name <<< "$line"
    [[ $name == *_ext-port ]] || continue
    # Keep ports still bound to a live server; delete detached/stale (leaked) ones.
    device_id=$(openstack port show "$pid" -c device_id -f value 2>/dev/null || true)
    if [[ -n $device_id && $device_id != None ]]; then
        openstack server show "$device_id" -c id -f value &>/dev/null && continue
    fi
    echo "Deleting leaked ext-port $pid ($name, device_id='${device_id}')"
    openstack port delete "$pid" && deleted=$((deleted + 1))
done

echo "Deleted $deleted leaked ext-port(s)"
