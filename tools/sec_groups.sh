#!/bin/bash -ex
# Add sec groups for basic access
secgroup=${1:-`openstack security group list --project admin| grep default| awk '{print $2}'`}
for port in 22 53 80 443; do
    openstack security group rule create $secgroup --protocol tcp --remote-ip 0.0.0.0/0 --dst-port $port --project admin ||:
done

openstack security group rule create $secgroup --protocol icmp --remote-ip 0.0.0.0/0 --project admin ||:
