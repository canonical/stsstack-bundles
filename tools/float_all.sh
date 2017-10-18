#!/bin/bash -ex
# Give all instances a floating IP address.
# Requires >= Newton openstack client

echo " + Floating all instances."

function get_ip_f() {
  # Get first unallocated floating IP
  openstack floating ip list | awk '/None/ { print $4 }' | head -n 1
}

fip_count=$(openstack floating ip list | awk '/None/ { print $4 }' | wc -l)
instances=$(openstack server list | grep ACTIVE | grep -v '\,' | awk '{ print $2 }')
inst_count=$(echo $instances | wc -w)

if [[ -z "$instances" ]]; then
  set +x
  echo " . It appears that no instance needs a floating IP."
  exit 0
fi

# Create floating IPs if necessary.
if (( $fip_count >= $inst_count)); then
  echo " . Already enough floating IPs."
else
  fip_diff=$(( $inst_count - $fip_count ))
  echo " + Creating $fip_diff more floating IPs."
  for m in $(seq 1 $fip_diff); do
    openstack floating ip create ext_net
  done
fi

# Allocate floating IPs to instances.
for instance in $instances; do
  ip_f=$(get_ip_f)
  echo " + Associating floating IP $ip_f to instance $instance."
  openstack server add floating ip $instance $ip_f
done

