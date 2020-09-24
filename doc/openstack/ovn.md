# Deploying OVN

The 20.02 release of the Openstack charms introduced OVN as an alternative to straight Openvswitch networking for Neutron.

To switch your networking to OVN simply use --ovn. You will need to be using the Openstack Train release or above.

Once deployed you will need to perform a few post-deployment actions;

First you need to unseal vault:

```
./tools/vault-unseal-and-authorise.sh
```

Now run the post-deploment configuration to setup the deployed cloud:

```
./configure.sh
```
