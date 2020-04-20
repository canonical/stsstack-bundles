#!/bin/bash -eux
lb=${1:-lb1}
member_vm=${2:-""}

`openstack loadbalancer list -c name -f value| grep -q $lb` && { echo "ERROR: a loadbalancer called $lb already exists"; exit 1; }

openstack loadbalancer create --name $lb --vip-subnet-id private_subnet

# Re-run the following until $lb shows ACTIVE and ONLINE status':
openstack loadbalancer show $lb
# wait for lb to be ACTIVE
while true; do
[ "`openstack loadbalancer show $lb -c provisioning_status -f value`" = "ACTIVE" ] \
    && break
echo "waiting for $lb"
done

openstack loadbalancer listener create --name listener1 --protocol HTTP --protocol-port 80 $lb
# wait for listener to be ACTIVE
while true; do
[ "`openstack loadbalancer listener show listener1 -c provisioning_status -f value`" = "ACTIVE" ] \
    && break
echo "waiting for listener1"
done

openstack loadbalancer pool create --name pool1 --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP
# wait for pool to be ACTIVE
while true; do
[ "`openstack loadbalancer pool show pool1 -c provisioning_status -f value`" = "ACTIVE" ] \
    && break
echo "waiting for pool1"
done

openstack loadbalancer healthmonitor create --delay 5 --max-retries 4 --timeout 10 --type HTTP --url-path / pool1
openstack loadbalancer healthmonitor list

# Add vm(s) to pool
if [ -z "$member_vm" ]; then
    readarray -t member_vm < <(openstack server list -c ID -f value)
    (( ${#member_vm[@]} )) || { echo "ERROR: could not find a vm to add to lb pool"; exit 1; }
fi

for member in ${member_vm[@]}; do
    netaddr=$(openstack port list --server $member --network private \
        -c "Fixed IP Addresses" -f value | sed -r "s/ip_address='([[:digit:]\.]+)',\s+.+/\1/g")
    member_id=$(openstack loadbalancer member create --subnet-id private_subnet \
        --address $netaddr --protocol-port 80 --format value --column id pool1)
    while true; do
        [[ $(openstack loadbalancer member show --format value \
            --column provisioning_status pool1 ${member_id}) = ACTIVE ]] \
            && break
        echo "waiting for member ${member} (${member_id})"
    done
done

openstack loadbalancer member list pool1

floating_ip=$(openstack floating ip create -f value -c floating_ip_address ext_net)
lb_vip_port_id=$(openstack loadbalancer show -f value -c vip_port_id $lb)
openstack floating ip set --port $lb_vip_port_id $floating_ip
