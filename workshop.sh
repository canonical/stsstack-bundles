#!/bin/bash

set -e -u -o pipefail

WORKSHOP_NAME=${WORKSHOP_NAME:-dev}

# Maps "<sdk>:<mount name>" to the host directory it should be backed by.
# The tilde is left unexpanded on purpose; expand_home handles it when used.
declare -A MOUNTS=(
    [copilot:copilot-config]='~/.copilot'
    [omp:omp-home]='~/.omp'
    [opencode:opencode-config]='~/.config/opencode'
    [opencode:opencode-data]='~/.local/share/opencode'
)

expand_home() {
    printf '%s' "${1/#\~/${HOME}}"
}

# Succeed when the sdk is present in the workshop. yq prints "null" for
# anything missing from the info document.
sdk_installed() {
    local sdk=$1
    [[ $(yq ".sdks.\"${sdk}\"" <<<"${INFO}") != null ]]
}

# Succeed when the mount already points at the wanted host directory,
# whether workshop reports it with a literal ~ or an expanded path.
mount_is_current() {
    local sdk=${1%%:*} mount=${1#*:} wanted=$2 current
    current=$(yq ".sdks.\"${sdk}\".mounts.\"${mount}\".\"host-source\"" <<<"${INFO}")
    [[ ${current} == "${wanted}" || ${current} == "$(expand_home "${wanted}")" ]]
}

if ! command -v yq >&/dev/null; then
    echo "Installing yq snap on host"
    sudo snap install yq
fi

if ! workshop info "${WORKSHOP_NAME}" >&/dev/null; then
    echo "Launching new workshop ${WORKSHOP_NAME}"
    workshop launch "${WORKSHOP_NAME}"
fi

# refresh only works on an active workshop, and start fails on one that is
# already active (status "ready"), so only start it when it is stopped.
if [[ $(workshop info "${WORKSHOP_NAME}" | yq '.status') == stopped ]]; then
    echo "Starting workshop ${WORKSHOP_NAME}"
    workshop start "${WORKSHOP_NAME}"
fi
workshop refresh "${WORKSHOP_NAME}" >/dev/null

# Query the workshop once and check every mount against that snapshot.
INFO=$(workshop info "${WORKSHOP_NAME}")

stale=()
for key in "${!MOUNTS[@]}"; do
    # A missing sdk has nothing to remount; this is not a stale host path.
    if ! sdk_installed "${key%%:*}"; then
        echo "Skipping ${key}: sdk '${key%%:*}' is not installed in ${WORKSHOP_NAME}" >&2
        continue
    fi
    if ! mount_is_current "${key}" "${MOUNTS[${key}]}"; then
        stale+=("${key}")
    fi
done

# The slow stop/start cycle happens once, and only if something is stale.
if ((${#stale[@]} > 0)); then
    echo "Mounting host configuration directories"
    workshop stop "${WORKSHOP_NAME}"
    for key in "${stale[@]}"; do
        echo "Mounting ${key} from host"
        host_path=$(expand_home "${MOUNTS[${key}]}")
        mkdir --parents "${host_path}"
        workshop remount "${WORKSHOP_NAME}/${key}" "${host_path}"
    done
    workshop start "${WORKSHOP_NAME}"
fi

echo "Workshop ready (connect with 'workshop shell')"
