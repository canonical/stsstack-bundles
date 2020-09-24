# Deploying Octavia

To deploy octavia as part of an Openstack deployment just add the --octavia overlay. Once deployed there are a few actions that must be taken to configure Octavia before it can be used.

NOTE: if you are using OVN as your neutron networking solution, you will need to perform the steps detailed in the ovn.md documentation before continuing

The following will download the Amphora image from (stsstack) Swift
that corresponds to the deployed release of Openstack and upload it to
your Glance. The optional argument `--image-format` specifies the
image format and defaults to `qcow2`.

```
tools/upload_octavia_amphora_image.sh --release <openstack-release-name> [--image-format {raw, qcow2}]
```

The following will configure Octavia's tls cert and lb-mgmt network.

```
tools/configure_octavia.sh
```

https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/app-octavia.html

## Using Octavia

Create an instance and secgroup rules

```
source novarc
./tools/sec_groups.sh &>2 &
./tools/instance_launch.sh 1 bionic
```

Give it a floating ip and ensure it can be pinged (once booted)
```
./tools/float_all.sh
ping __FIP__
```

Install apache
```
ssh __FIP__ -- 'sudo apt update; sudo apt install apache2 -y'
```

Now create a loadbalancer adding the vm just created to the LB pool
```
tools/create_octavia_lb.sh __VM_UUID__
```

Now check that your loadbalancer is up and load balancing to port 80 in the vm

```
lb_vip=$(openstack loadbalancer show lb1 -c vip_address -f value)
lb_fip=$(openstack floating ip list|egrep -v "\+-+|ID"| awk "\\$6==\\"$lb_vip\\" {print \\$4}")
nc -vz  $lb_fip 80
```
