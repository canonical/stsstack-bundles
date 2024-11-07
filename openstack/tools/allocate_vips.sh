#!/bin/bash

# Allocate the last 20 IP addresses, which could be considered for
# VIPs in OpenStack

source ~/novarc
num_vips=20
subnet="subnet_${OS_USERNAME}-psd"

cidr=$(openstack subnet show ${subnet} -c cidr -f value 2>/dev/null)

net_end=$(awk -F'.' '/HostMax/{print $NF}' <<<$(ipcalc -b $cidr))

vip_start_suffix=$((net_end - num_vips + 1))
net_pre=$(echo $cidr| sed -r 's/([0-9]+\.[0-9]+\.[0-9]+).+/\1/g')

j=1

for i in $(seq ${vip_start_suffix} ${net_end}); do
    echo openstack port create --network net_${OS_USERNAME}-psd \
        --fixed-ip subnet=subnet_${OS_USERNAME}-psd,ip-address=${net_pre}.$i \
        --disable --os-cloud ps6 ps6-vip-ip$( printf "%02d" $j )
    j=$((j+1))
done