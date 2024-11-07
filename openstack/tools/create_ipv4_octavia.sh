#!/bin/bash

set -u -e -x

# wait for services start
while true; do
    [[ `juju status keystone --format json | jq -r '.applications.keystone.units."keystone/0"."workload-status".current'` = active ]] \
        && break
    if [[ `juju status keystone --format json | \
            jq -r '.applications.keystone.units."keystone/0"."workload-status".current'` = error ]]; then
        echo "ERROR: Octavia deployment failed"
        break
    fi
done

echo INFO: create temp novarc.services and extract octavia password
touch /tmp/novarc.services

cat << EOF > /tmp/novarc.services
OS_PROJECT_DOMAIN_NAME=service_domain
OS_USERNAME=octavia
OS_PROJECT_NAME=services
OS_USER_DOMAIN_NAME=service_domain
OS_PASSWORD=$(juju exec --unit octavia/0 "grep -v "auth" /etc/octavia/octavia.conf | grep password" | awk '{print $3}')
EOF
source /tmp/novarc.services

echo INFO: create octavia network, subnet, router, add subnet to router
openstack network create lb-mgmt-net --tag charm-octavia
openstack subnet create --tag charm-octavia --subnet-range 10.100.0.0/24 --dhcp  --ip-version 4 --network lb-mgmt-net lb-mgmt-subnet
openstack router create lb-mgmt --tag charm-octavia
openstack router add subnet lb-mgmt lb-mgmt-subnet

echo INFO: add security rules
openstack security group create lb-mgmt-sec-grp --tag charm-octavia
openstack security group create lb-health-mgr-sec-grp --tag charm-octavia-health
openstack security group rule create lb-mgmt-sec-grp --protocol icmp
openstack security group rule create lb-mgmt-sec-grp --protocol tcp --protocol tcp --dst-port 22
openstack security group rule create lb-mgmt-sec-grp --protocol tcp --dst-port 9443
