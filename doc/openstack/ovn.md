# Deploying OVN

The 20.02 release of the Openstack charms introduced OVN as an alternative to straight Openvswitch networking for Neutron.

To switch your networking to OVN simply use --ovn. You will need to be using the Openstack Train release or above.

Once deployed you will need to perform a few post-deployment actions;

First you need to unseal vault:

```
./tools/vault-unseal-and-authorise.sh
```

Since ovn requires vault to be deployed and used for cert management you need to install the vault-generated CA to be able to speak to endpoints:

```
./tools/install_local_ca.sh
```

Now you need to add an extra port to your nodes running ovn-chassis (this the port that will be used as the "external network"):

```
./bin/add-data-ports.sh
```

And of course run the post-deploment configuration to setup the deployed cloud:

```
./configure.sh
```
