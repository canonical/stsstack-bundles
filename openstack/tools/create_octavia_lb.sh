#!/bin/bash

set -e -u

lb=lb1
declare -a member_vm=()
member_subnet=
provider=amphora
protocol=HTTP
protocol_port=80
hm_protocol=
vip_subnet=private_subnet

while (( $# > 0 )); do
    case $1 in
        --name)
            if (( $# < 2 )); then
                echo "missing name"
                exit 1
            fi
            lb=$2
            shift
            ;;
        --member-vm)
            if (( $# < 2 )); then
                echo "missing member VM"
                exit 1
            fi
            member_vm+=( "$2" )
            shift
            ;;
        --member-subnet)
            if (( $# < 2 )); then
                echo "missing member subnet name or ID"
                exit 1
            fi
            member_subnet=$2
            shift
            ;;
        --provider)
            if (( $# < 2 )); then
                echo "missing provider"
                exit 1
            fi
            provider=$2
            shift
            ;;
        --protocol)
            if (( $# < 2 )); then
                echo "missing protocol"
                exit 1
            fi
            protocol=$2
            shift
            ;;
        --protocol-port)
            if (( $# < 2 )); then
                echo "missing protocol port"
                exit 1
            fi
            protocol_port=$2
            shift
            ;;
        --healthmonitor-protocol)
            if (( $# < 2 )); then
                echo "missing protocol for healthmonitor"
                exit 1
            fi
            hm_protocol=$2
            shift
            ;;
        --vip-subnet)
            if (( $# < 2 )); then
                echo "missing vip subnet name or ID"
                exit 1
            fi
            vip_subnet=$2
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage:

$(basename "$0") [options]

--name NAME                 The loadbalancer name base, default = ${lb} (things
                            such as listener and pool are named using this base)
--member-vm NAME            The name of the member VM. Can be used multiple times.
                            If not provided use the first VM running.
--provider PROVIDER         The Octavia provider {amphora, ovn}, default = ${provider}
--protocol PROTOCOL         TCP, HTTP, ..., default = ${protocol}
--protocol-port PORT        Port to use, default = ${protocol_port}
--vip-subnet SUBNET         Name or ID of VIP subnet ${vip_subnet}
--member-subnet SUBNET      Optional member subnet
EOF
            exit 0
            ;;
        *)
            echo "unknown argument $1"
            exit 1
            ;;
    esac
    shift
done
if [[ -z "$hm_protocol" ]]; then
    hm_protocol=${protocol}
fi
url_path=
if [[ ${hm_protocol} == HTTP ]]; then
    url_path="--url-path /"
fi

if openstack loadbalancer show ${lb} > /dev/null 2>&1; then
    echo "ERROR: a loadbalancer called ${lb} already exists"
    exit 1
fi

LB_ID=$(openstack loadbalancer create \
    --name ${lb} \
    --vip-subnet-id ${vip_subnet} \
    --provider ${provider} \
    --format value \
    --column id)

# wait for lb to be ACTIVE
echo -n "waiting for $lb"
while true; do
    if [[ $(openstack loadbalancer show ${LB_ID} --column provisioning_status --format value) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

LISTENER_ID=$(openstack loadbalancer listener create \
    --name ${lb}-listener --protocol ${protocol} --protocol-port ${protocol_port} \
    --format value --column id ${lb})

# wait for listener to be ACTIVE
echo -n "waiting for ${lb}-listener"
while true; do
    if [[ $(openstack loadbalancer listener show ${LISTENER_ID} --column provisioning_status --format value) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

LB_ALGORITHM=ROUND_ROBIN
if [[ ${provider} == ovn ]]; then
    LB_ALGORITHM=SOURCE_IP_PORT
fi
POOL_ID=$(openstack loadbalancer pool create \
    --name ${lb}-pool \
    --lb-algorithm ${LB_ALGORITHM} \
    --listener ${LISTENER_ID} \
    --protocol ${protocol} \
    --format value --column id)

echo -n "waiting for ${lb}-pool"
while true; do
    if [[ $(openstack loadbalancer pool show ${POOL_ID} --column provisioning_status --format value) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

HM_ID=$(openstack loadbalancer healthmonitor create \
    --name ${lb}-healthmonitor --delay 5 --max-retries 4 --timeout 10 --type ${hm_protocol} ${url_path} ${POOL_ID} \
    --format value --column id)

# Add vm(s) to pool
if (( ${#member_vm[@]} == 0 )); then
    readarray -t member_vm < <(openstack server list --column ID --format value)
    if ((${#member_vm[@]}==0)); then
        echo "ERROR: could not find a vm to add to lb pool"
        exit 1
    fi
fi

for member in "${member_vm[@]}"; do
    netaddr=$(openstack port list --server ${member} --column "Fixed IP Addresses" --format value | \
                sed -rn -e "s/.+ip_address='([[:digit:]\.]+)',\s+.+/\1/" \
                        -e "s/.+ip_address':\s+'([[:digit:]\.]+)'}.+/\1/p")
    member_id=$(openstack loadbalancer member create --address ${netaddr} \
                    $( [[ -n ${member_subnet} ]] && echo "--subnet-id ${member_subnet}" ) \
                    --protocol-port ${protocol_port} --format value --column id ${POOL_ID})

    echo -n "waiting for member ${member} (${member_id})"
    while true; do
        if [[ $(openstack loadbalancer member show --format value \
            --column provisioning_status ${POOL_ID} ${member_id}) = ACTIVE ]]; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo
done

floating_ip=$(openstack floating ip create --format value --column floating_ip_address ext_net)
lb_vip_port_id=$(openstack loadbalancer show --format value --column vip_port_id ${LB_ID})

openstack floating ip set --port ${lb_vip_port_id} ${floating_ip}

echo "The load balancer is at floating IP ${floating_ip}"

if [[ ${hm_protocol} != HTTP ]]; then
    exit
fi

L7_POLICY1_ID=$(openstack loadbalancer l7policy create --action REDIRECT_TO_POOL \
    --redirect-pool ${POOL_ID} --name ${lb}-l7policy1 --format value --column id ${LISTENER_ID})
echo -n "waiting for ${lb}-l7policy1"
while true; do
    if [[ $(openstack loadbalancer l7policy show ${L7_POLICY1_ID} --format value --column provisioning_status) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

L7_RULE1_ID=$(openstack loadbalancer l7rule create --compare-type STARTS_WITH --type PATH \
    --value /js --format value --column id ${L7_POLICY1_ID})
echo -n "waiting for ${L7_RULE1_ID}"
while true; do
    if [[ $(openstack loadbalancer l7rule show --format value --column provisioning_status ${L7_POLICY1_ID} ${L7_RULE1_ID}) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

L7_POLICY2_ID=$(openstack loadbalancer l7policy create --action REDIRECT_TO_POOL \
    --redirect-pool ${lb}-pool --name ${lb}-l7policy2 --format value --column id ${lb}-listener)
echo -n "waiting for ${lb}-l7policy2"
while true; do
    if [[ $(openstack loadbalancer l7policy show ${L7_POLICY2_ID} --format value --column provisioning_status) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

L7_RULE2_ID=$(openstack loadbalancer l7rule create --compare-type STARTS_WITH --type PATH \
    --value /images --format value --column id ${L7_POLICY2_ID})
echo -n "waiting for ${L7_RULE2_ID}"
while true; do
    if [[ $(openstack loadbalancer l7rule show --format value --column provisioning_status ${L7_POLICY2_ID} ${L7_RULE2_ID}) == ACTIVE ]]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

echo "Load balancer is active"
