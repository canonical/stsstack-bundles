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

# Create Nova keypair. Don't clobber existing keyfile in case it is being used for multiple models at once.
prvkey=~/testkey.priv
pubkey=~/testkey.pub
if ! openstack keypair show testkey; then
    if [ -r $prvkey ] && [ -r $pubkey ]; then
        openstack keypair create testkey --public-key $pubkey
    else
        openstack keypair create testkey > $prvkey
        openstack keypair show testkey --public-key > $pubkey
    fi
    chmod 600 $prvkey
fi

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

echo 'Hint: use ssh -i ~/testkey.pem ubuntu@<ip> to access new instances (may also need a floating IP, see ./tools/float_all.sh).'
