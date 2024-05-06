#!/bin/bash -ex
# Add sec groups for basic access
# NOTE: this is for the overcloud; run `source novarc` first.
`env| egrep -q "^OS_.*DOMAIN.*|/v3"` && v3args="--project-domain admin_domain" || v3args=""
secgroup=${1:-`openstack security group list --project admin $v3args| grep default| awk '{print $2}'`}
for port in 22 53 80 443; do
    openstack security group rule create $secgroup --protocol tcp --remote-ip 0.0.0.0/0 --dst-port $port --project admin $v3args ||:
done

openstack security group rule create $secgroup --protocol icmp --remote-ip 0.0.0.0/0 --project admin $v3args ||:
