#!/bin/bash -eux
id=$(uuidgen)
project_name=${1:-project-$id}
domain=${2:-user_domain}
network=${3:-172.16.0.0/24}

# ensure deps
dpkg -s ipcalc &>/dev/null || sudo apt install ipcalc -y

echo "Creating project $project_name"

openstack domain show $domain 2>/dev/null || openstack domain create $domain
p_id=$(openstack project create --domain $domain --enable $project_name -c id -f value)
u_id=$(openstack user create --project $p_id --password ubuntu --enable --email $project_name@dev.null user-$id --domain $domain -c id -f value)

# general role
openstack role add --user $u_id --user-domain $domain --project $p_id --project-domain $domain member

# add roles for octavia if its in use
if (($(juju status octavia --format=json 2>/dev/null | jq '.machines| length'))); then
    openstack role add --user $u_id --user-domain $domain --project $p_id --project-domain $domain load-balancer_observer &
    openstack role add --user $u_id --user-domain $domain --project $p_id --project-domain $domain load-balancer_member &
    wait
fi

openstack role assignment list --user $u_id

cat <<EOF >novarc.$project_name
export OS_AUTH_URL=$OS_AUTH_URL
export OS_REGION_NAME=RegionOne
export OS_PROJECT_NAME=$project_name
export OS_PROJECT_DOMAIN_NAME=$domain
export OS_USER_DOMAIN_NAME=$domain
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD=ubuntu
export OS_USERNAME=user-$id
EOF

net_start=$(ipcalc $network | awk '$1=="HostMin:" {print $2}')
net_end=$(ipcalc $network | awk '$1=="HostMax:" {print $2}')
d=${net_start##*.}
net_start=${net_start%.*}.$((++d))

n_id="$(openstack network create --enable private --project $p_id --project-domain $domain -c id -f value)"
sn_id="$(openstack subnet create --allocation-pool start=$net_start,end=$net_end \
    --subnet-range $network --dhcp --ip-version 4 --network $n_id private_subnet --project $p_id --project-domain $domain -c id -f value)"

openstack router create ${project_name}-router --project $p_id --project-domain $domain
openstack router add subnet ${project_name}-router $sn_id &
openstack router set --external-gateway ext_net ${project_name}-router &
wait

echo "Credentials for new project available at novarc.$project_name"

echo "Done."
