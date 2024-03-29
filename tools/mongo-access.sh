#!/bin/bash

set -u

: "${machine:=0}"
: "${model:=controller}"
: "${ip_address:=}"

juju=$(command -v juju)

while (( $# > 0 )); do
    case $1 in
        -h|--help)
            cat <<EOF
Usage:

$(basename $0) [--machine ID] [--model MODEL]

Options:

--machine ID    The machine ID to connect to (default ${machine})
--model MODEL   The model the machine is a part of (default ${model})
--ip IP         Instead of using "juju ssh", directly "ssh" to IP. This option
                    can become useful in case the juju controller is not
                    responding and "juju ssh" cannot be used.
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
        --ip)
            shift
            ip_address="$1"
            ;;
    esac
    shift
done

read -r -d '' cmds <<'EOF'
conf=/var/lib/juju/agents/machine-*/agent.conf
user=$(sudo awk '/tag/ {print $2}' ${conf})
password=$(sudo awk '/statepassword/ {print $2}' ${conf})
if [ -f /snap/bin/juju-db.mongo ]; then
    client=/snap/bin/juju-db.mongo
elif [ -f /usr/lib/juju/mongo*/bin/mongo ]; then
    client=/usr/lib/juju/mongo*/bin/mongo
else
    client=/usr/bin/mongo
fi
${client} 127.0.0.1:37017/juju --authenticationDatabase admin \
    --ssl --sslAllowInvalidCertificates \
    --username "${user}" --password "${password}"
EOF
if [[ -z ${ip_address} ]]; then
    ${juju} ssh -m "${model}" "${machine}" "${cmds}"
else
    ssh -t ${ip_address} "${cmds}"
fi
