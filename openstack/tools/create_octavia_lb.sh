#!/bin/bash -eux

lb=lb1
member_vm=
protocol=HTTP
protocol_port=80

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
            member_vm=$2
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
        -h|--help)
            cat <<EOF
Usage:

$(basename $0) [options]

--name NAME              The loadbalancer name, default = $lb
--member-vm NAME         The name of the member VM. If not provided
                         use the first VM running.
--protocol PROTOCOL      TCP, HTTP, ..., default = $protocol
--protocol-port PORT     Port to use, default = $protocol_port
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

url_path=
if [[ ${protocol} == HTTP ]]; then
    url_path="--url-path /"
fi

`openstack loadbalancer list -c name -f value| grep -q $lb` && { echo "ERROR: a loadbalancer called $lb already exists"; exit 1; }

LB_ID=$(openstack loadbalancer create --name $lb \
    --vip-subnet-id private_subnet --format value --column id)

# Re-run the following until $lb shows ACTIVE and ONLINE status':
openstack loadbalancer show ${LB_ID}

# wait for lb to be ACTIVE
while true; do
    [[ `openstack loadbalancer show ${LB_ID} -c provisioning_status -f value` = ACTIVE ]] \
        && break
    echo "waiting for $lb"
done

LISTENER_ID=$(openstack loadbalancer listener create \
    --name listener1 --protocol ${protocol} --protocol-port ${protocol_port} \
    --format value --column id $lb)
# wait for listener to be ACTIVE
while true; do
    [[ `openstack loadbalancer listener show ${LISTENER_ID} -c provisioning_status -f value` = ACTIVE ]] \
        && break
    echo "waiting for listener1"
done

POOL_ID=$(openstack loadbalancer pool create \
    --name pool1 --lb-algorithm ROUND_ROBIN --listener ${LISTENER_ID} --protocol ${protocol} \
    --format value --column id)
# wait for pool to be ACTIVE
while true; do
    [[ `openstack loadbalancer pool show ${POOL_ID} -c provisioning_status -f value` = ACTIVE ]] \
        && break
    echo "waiting for pool1"
done

HM_ID=$(openstack loadbalancer healthmonitor create \
    --name hm1 --delay 5 --max-retries 4 --timeout 10 --type ${protocol} ${url_path} ${POOL_ID} \
    --format value --column id)
openstack loadbalancer healthmonitor list

# Add vm(s) to pool
if [ -z "$member_vm" ]; then
    readarray -t member_vm < <(openstack server list -c ID -f value)
    (( ${#member_vm[@]} )) || { echo "ERROR: could not find a vm to add to lb pool"; exit 1; }
fi

for member in ${member_vm[@]}; do
    netaddr=$(openstack port list --server $member --network private -c "Fixed IP Addresses" -f value| \
                sed -rn -e "s/.+ip_address='([[:digit:]\.]+)',\s+.+/\1/" \
                        -e "s/.+ip_address':\s+'([[:digit:]\.]+)'}.+/\1/p")
    member_id=$(openstack loadbalancer member create --subnet-id private_subnet \
        --address $netaddr --protocol-port ${protocol_port} --format value --column id ${POOL_ID})
    while true; do
        [[ $(openstack loadbalancer member show --format value \
            --column provisioning_status ${POOL_ID} ${member_id}) = ACTIVE ]] \
            && break
        echo "waiting for member ${member} (${member_id})"
    done
done

openstack loadbalancer member list ${POOL_ID}

floating_ip=$(openstack floating ip create -f value -c floating_ip_address ext_net)
lb_vip_port_id=$(openstack loadbalancer show -f value -c vip_port_id ${LB_ID})
openstack floating ip set --port $lb_vip_port_id $floating_ip
