#!/bin/bash -eux
project_name=$1
domain=${2:-user_domain}

echo "Deleting project $project_name"

openstack loadbalancer list -c id -f value --project $project_name| xargs openstack loadbalancer delete --cascade 2>/dev/null || true
openstack server list -c ID -f value --project $project_name --project-domain $domain| xargs openstack server delete 2>/dev/null || true
openstack floating ip list --project $project_name --project-domain $domain -c ID -f value| xargs -l openstack floating ip delete 2>/dev/null || true

openstack router unset --external-gateway ${project_name}-router &

readarray -t ports<<<`openstack port list --router ${project_name}-router -c id -c device_owner -f value| awk '$2=="network:ha_router_replicated_interface" {print $1}'`
((${#ports[@]})) && [ -n "${ports[0]}" ] || \
    readarray -t ports<<<`openstack port list --router ${project_name}-router -c id -c device_owner -f value| awk '$2=="network:router_interface_distributed" {print $1}'`

declare -A subnets=()
if ((${#ports[@]})) && [ -n "${ports[0]}" ]; then
    for port in ${ports[@]}; do
        openstack router remove port ${project_name}-router $port 2>/dev/null && continue || true
        subnet=`openstack port show $port -c fixed_ips -f value| sed -rn "s/.+subnet_id='([[:alnum:]\-]+).*'/\1/p"`
        openstack router remove subnet ${project_name}-router $subnet
        subnets[$subnet]=true
    done
fi
openstack router delete ${project_name}-router &

# Add another other subnets
for _subnet in `openstack subnet list --project $project_name -c ID -f value`; do
    subnets[$_subnet]=true
done

for subnet in ${!subnets[@]}; do
    n_id=`openstack subnet show $subnet -c network_id -f value`
    openstack subnet delete $subnet
    openstack network delete $n_id || true
done

openstack user list --project $project_name --domain $domain -c ID -f value| xargs openstack user delete
openstack project delete ${project_name}

echo "Done."
