===============================================
Manila generic driver ``DHSS=True`` charm guide
===============================================

1) Deploy openstack bundle
==========================

Generate bundle::

  ./generate-bundle.sh --series jammy --release yoga --name jy-manila-ovn --cinder-lvm --run

Initialise vault, wait for it to settle, then run **./configure**

2) Deploy manila
================

In the following commands, use **"--to <compute_node_machine_number>"**::

  juju deploy manila --channel yoga/stable --to 8

  juju deploy manila-generic --channel yoga/stable

  juju deploy mysql-router manila-mysql-router --channel 8.0/stable --series jammy

  juju integrate manila-mysql-router:db-router mysql:db-router

  juju integrate manila:shared-db manila-mysql-router:shared-db

  juju integrate manila rabbitmq-server

  juju integrate manila keystone

Wait for active/idle/blocked juju status, then proceed::

  juju integrate manila:manila-plugin manila-generic

Wait for active/idle/blocked juju status.

3) Fix template issues workaround (bad string)
==============================================

There is a bad string in the manila templates::

  juju ssh manila/0 -- sudo -s

  vi /var/lib/juju/agents/unit-manila-generic-0/charm/templates/parts/authentication_data

Delete the lines::

  {{ # Defense mechanism introduced in the charm release 21.10 because of a
       relation data key renaming, and would be safe to remove 2 releases later.
  #}}

4) Set config options
=====================

Configure manila charms::

  juju config manila default-share-backend=generic default-share-type=default debug=true verbose=false share-protocols=NFS

  juju config manila-generic driver-service-instance-flavor-id=2 driver-connect-share-server-to-tenant-network=false driver-service-instance-password=manila driver-auth-type=password

Wait for active/idle/blocked juju status.

5) Fix template issues workaround (glance)
==========================================

Copy the entire **[cinder]** section of **/etc/manila/manila.conf** and paste it around the middle in **/var/lib/juju/agents/unit-manila-0/charm/templates/rocky/manila.conf** as **[glance]**

Flip the verbose config in manila to apply the change::

  juju config manila verbose=true

6) Acquire and upload service image
===================================

Run on your laptop::

  wget https://tarballs.opendev.org/openstack/manila-image-elements/images/manila-service-image-master.qcow2

Then rsync it to your bastion and upload it::

  rsync -vza manila-service-image-master.qcow2  ubuntu@10.149.138.40:~/images

  openstack image create --disk-format qcow2 manila-service-image --file ~/images/manila-service-image-master.qcow2

7) Create a client VM
=====================

Create a client VM to access the share later::

  openstack keypair create bastion --public-key ~/.ssh/id_rsa.pub

  openstack server create --key-name bastion --network private --image jammy --flavor 2 ins1

  openstack floating ip create ext_net

  openstack server add floating ip ins1 <floating_ip>

  ~/stsstack-bundles/openstack/tools/sec_groups.sh

  ping <floating_ip>

8) Create a share
=================

Install the CLI package to enable the **openstack share** commands::

  sudo apt install python3-manilaclient

  openstack share service list

Confirm that the **manila-share** service **@generic** is up, then proceed::

  openstack share type create default true

  openstack network list

  openstack share network create --neutron-net-id <private_net_id> --neutron-subnet-id <private__subnet_id> --name sn1

  openstack share create NFS 1 --name s1 --share-network sn1

  openstack share list

Wait for the share to become available.

9) Access the share and test creating a file
============================================

Add access rule to the share::

  openstack share access create s1 ip 0.0.0.0/0

  openstack share show s1

Take note of the **export location path**.

SSH to the client VM::

  ssh ubuntu@<floating ip>

  ping <export_location_ip>

  sudo apt install nfs-common

  mkdir test

  sudo mount -t nfs <export_location_path> test

  cd test

  df -h

Confirm path is mounted and shows ~1GB of size.

Write a file::

  echo hello > hi

  ls -lha

  cat hi
