#!/bin/bash

set -u

: "${machine:=0}"
: "${model:=controller}"

while (( $# > 0 )); do
    case $1 in
        -h|--help)
            cat <<EOF
Usage:

$(basename $0) [--machine ID] [--model MODEL]

Options:

--machine ID    The machine ID to connect to (default ${machine})
--model MODEL   The model the machine is a part of (default ${model})
EOF
            exit 0
            ;;
        --machine)
            shift
            machine="$1"
            ;;
        --model)
            shift
            model="$1"
            ;;
    esac
    shift
done

read -d '' cmds <<'EOF'
conf=/var/lib/juju/agents/machine-*/agent.conf
user=`sudo grep tag $conf | cut -d' ' -f2`
password=`sudo grep statepassword $conf | cut -d' ' -f2`
if [ -f /snap/bin/juju-db.mongo ]; then
    client=/snap/bin/juju-db.mongo
elif [ -f /usr/lib/juju/mongo*/bin/mongo ]; then
    client=/usr/lib/juju/mongo*/bin/mongo
else
    client=/usr/bin/mongo
fi
$client 127.0.0.1:37017/juju --authenticationDatabase admin \
    --ssl --sslAllowInvalidCertificates \
    --username "$user" --password "$password"
EOF
juju ssh -m "${model}" "${machine}" "${cmds}"
