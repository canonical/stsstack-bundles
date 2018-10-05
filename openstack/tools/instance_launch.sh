#!/bin/bash -ex
# Launch N quantity of XYZ instances
# Presumes glance images exist and have been imported using the
# accompanying configure script.

instance_qty=$1
image_name=$2
if [ -z "$instance_qty" ] || [ -z "$image_name" ]; then
  set +x
  echo "Launches N quantity of XYZ instances.
Usage:  <this script> <qty of instances> <glance image name>
   ex:  ./instance_launch.sh 10 xenial-ppc64el
   Cirros images will use m1.cirros flavor.
   All others will use m1.small flavor."
  exit 1
fi

# Key nova and ~/testkey.pem
openstack keypair show testkey ||\
    { openstack keypair create testkey > ~/testkey.pem; chmod 600 ~/testkey.pem; }

# Grab private network ID
net_id=$(openstack network list | awk '/private/ {print $2}')

# Determining flavor to use
if [[ "${image_name}" == *cirros* ]]; then
  flavor="m1.cirros"
else
  flavor="m1.small"
fi

# Create instances
server_name="${image_name}-$(date +'%H%M%S')"
openstack server create --wait --image $image_name --flavor $flavor --key-name testkey --nic net-id=${net_id} --min $instance_qty --max $instance_qty $server_name

# Hint:  use ssh -i ~/testkey.pem ubuntu@<ip> to access new instances (may also need a floating IP).

