# Deploying OVN

The `20.02` release of the Openstack charms introduced OVN as an alternative to straight Open vSwitch networking for Neutron.

To switch your networking to OVN simply use `--ovn`. You will need to be using the Openstack Train release or above.

Once deployed you will need to perform a few post-deployment actions;

First you need to unseal vault:

```console
./tools/vault-unseal-and-authorise.sh
```

Now run the post-deployment configuration to setup the deployed cloud:

```console
./configure.sh
```
