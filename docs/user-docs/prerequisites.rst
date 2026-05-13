Prerequisites
=============

These are the general prerequisites required to follow along with the tutorials.

Juju controller
---------------

Get a juju controller on ``Serverstack`` (the undercloud).

1. source your ``serverstack`` ``novarc``
2. ``juju add-cloud`` and follow the prompts; they should be auto-filled with info from the environment after sourcing the ``Serverstack`` ``novarc``
3. ``juju autoload-credentials --client``
4. ``juju bootstrap serverstack serverstack --bootstrap-constraints="allocate-public-ip=true"``

We want a public (floating) IP here so we can use the controller instance as a jump host for accessing other instances (e.g. the units for charmed OpenStack). 
We can't deploy all units with a public IP because we will reach the quota for floating IPs on ``Serverstack``.

Tunnel into the undercloud network
----------------------------------

You will need access to the internal subnet available to you on ``Serverstack`` (all instances created via juju will have an address on this subnet).
This is so you can do things like juju ssh to the instances, unseal the vault using the ``stsstack-bundles`` scripts, access the cloud using the openstack CLI, etc. 
If you are running these steps from inside a bastion instance on ``Serverstack``, you may skip this step.

Otherwise, set up a tunnel into your ``Serverstack`` private subnet. This can be done via ``sshuttle`` to the juju controller instance 
(which was deployed with a public floating IP), or any other instance with a public floating IP (e.g. if you already have a bastion instance). 
``10.5.0.0/16`` is used as an example; your subnet may be different.

.. code-block:: console

    sshuttle -r <IP_OF_JUJU_CONTROLLER> 10.5.0.0/16

.. toctree::
   :hidden:
   :maxdepth: 2

   usage
