===============================================
Manila generic driver ``DHSS=True`` charm guide
===============================================

Deploy openstack bundle
=======================

Generate bundle:

.. code-block:: console

  ./generate-bundle.sh --series jammy --release yoga --name jy-manila-ovn --cinder-lvm --run

Initialise vault, wait for it to settle, then run **./configure**

Deploy manila
=============

In the following commands, use **"--to <compute_node_machine_number>"**

.. code-block:: console

  juju deploy manila --channel yoga/stable --to 8
  juju deploy manila-generic --channel yoga/stable
  juju deploy mysql-router manila-mysql-router --channel 8.0/stable --series jammy
  juju integrate manila-mysql-router:db-router mysql:db-router
  juju integrate manila:shared-db manila-mysql-router:shared-db
  juju integrate manila rabbitmq-server
  juju integrate manila keystone

Wait for active/idle/blocked juju status, then proceed

.. code-block:: console

  juju integrate manila:manila-plugin manila-generic

Wait for active/idle/blocked juju status.

Fix template issues workaround (bad string)
===========================================

There is a bad string in the manila templates

.. code-block:: console

  juju ssh manila/0 -- sudo -s
  vi /var/lib/juju/agents/unit-manila-generic-0/charm/templates/parts/authentication_data

Delete the lines:

.. code-block:: console

  {{ # Defense mechanism introduced in the charm release 21.10 because of a
       relation data key renaming, and would be safe to remove 2 releases later.
  #}}

Set config options
==================

Configure manila charms

.. code-block:: console

  juju config manila default-share-backend=generic default-share-type=default debug=true verbose=false share-protocols=NFS
  juju config manila-generic driver-service-instance-flavor-id=2 driver-connect-share-server-to-tenant-network=false driver-service-instance-password=manila driver-auth-type=password

Wait for active/idle/blocked juju status.

Fix template issues workaround (glance)
=======================================

Copy the entire **[cinder]** section of **/etc/manila/manila.conf** and paste it around the middle in **/var/lib/juju/agents/unit-manila-0/charm/templates/rocky/manila.conf** as **[glance]**

Flip the verbose config in manila to apply the change

.. code-block:: console

  juju config manila verbose=true

Acquire and upload service image
================================

Run on your laptop

.. code-block:: console

  wget https://tarballs.opendev.org/openstack/manila-image-elements/images/manila-service-image-master.qcow2

Then rsync it to your bastion and upload it

.. code-block:: console

  rsync -vza manila-service-image-master.qcow2  ubuntu@10.149.138.40:~/images
  openstack image create --disk-format qcow2 manila-service-image --file ~/images/manila-service-image-master.qcow2

Create a client VM
==================

Create a client VM to access the share later

.. code-block:: console

  openstack keypair create bastion --public-key ~/.ssh/id_rsa.pub
  openstack server create --key-name bastion --network private --image jammy --flavor 2 ins1
  openstack floating ip create ext_net
  openstack server add floating ip ins1 <floating_ip>
  ~/stsstack-bundles/openstack/tools/sec_groups.sh
  ping <floating_ip>

Create a share
==============

Install the CLI package to enable the **openstack share** commands

.. code-block:: console

  sudo apt install python3-manilaclient
  openstack share service list

Confirm that the **manila-share** service **@generic** is up, then proceed

.. code-block:: console

  openstack share type create default true
  openstack network list
  openstack share network create --neutron-net-id <private_net_id> --neutron-subnet-id <private__subnet_id> --name sn1
  openstack share create NFS 1 --name s1 --share-network sn1
  openstack share list

Wait for the share to become available.

Access the share and test creating a file
=========================================

Add access rule to the share

.. code-block:: console

  openstack share access create s1 ip 0.0.0.0/0
  openstack share show s1

Take note of the **export location path**.

SSH to the client VM

.. code-block:: console

  ssh ubuntu@<floating ip>
  ping <export_location_ip>
  sudo apt install nfs-common
  mkdir test
  sudo mount -t nfs <export_location_path> test
  cd test
  df -h

Confirm path is mounted and shows ~1GB of size.

Write a file

.. code-block:: console

  echo hello > hi
  ls -lha
  cat hi
