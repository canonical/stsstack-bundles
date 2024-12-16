# Tutorial for deploying on serverstack

Serverstack is an internal deployment of OpenStack,
but these instructions may help for deploying on top of any OpenStack undercloud.

First some terminology:

- undercloud: the OpenStack cloud on which we will deploy OpenStack here, for example, Serverstack.
- overcloud: the OpenStack cloud which we are deploying here.

The overcloud is deployed onto the undercloud.

## Juju controller

Now, first step is to get a juju controller on Serverstack (the undercloud).

1. source your serverstack novarc
2. `juju add-cloud` and follow the prompts; they should be autofilled with info from the environment after sourcing the Serverstack novarc
3. `juju autoload-credentials --client`
4. `juju bootstrap serverstack serverstack --bootstrap-constraints="allocate-public-ip=true"`

We want a public (floating) ip here so we can use the controller instance as a jumphost for accessing other instances (eg. the units for charmed openstack).
We can't deploy all units with a public ip because we will reach the quota for floating ips on Serverstack.

## Tunnel into the undercloud network

You will need access to the internal subnet available to you on Serverstack (all instances created via juju will have an address on this subnet) -
this is so you can do things like juju ssh to the instances, unseal vault using the stsstack-bundles scripts, access the cloud using the openstack cli, etc.
If you are running these steps from inside a bastion instance on Serverstack, you may skip this step.

Otherwise, set up a tunnel into your Serverstack private subnet.
This can be done via sshuttle to the juju controller instance (which was deployed with a public floating ip),
or any other instance with a public floating ip (eg. if you already have a bastion instance).
10.5.0.0/16 is used as an example; your subnet may be different.

```
sshuttle -r IP_OF_JUJU_CONTROLLER 10.5.0.0/16
```

## Deploy the OpenStack overcloud

Now we can start deploying!

Use the `generate-bundle.sh` script in this directory,
using the flags to set the desired config,
and include the `--run` option to deploy it.
For example, to create a juju model named `openstack`,
and deploy a OpenStack Yoga release on Jammy machines:

```
./generate-bundle.sh --name openstack -r yoga -s jammy --run
```

This will output several lines from juju as it deploys the bundle,
and then a message about post deployment actions:


```
Deploy of bundle completed.

Post-Deployment Info/Actions:

[common]
  - run ./tools/vault-unseal-and-authorise.sh
  - run ./configure to initialise your deployment
  - source novarc
  - add rules to default security group: ./tools/sec_groups.sh
```

We'll come back to the post deploy steps, but for now,
check `juju status` and wait for all the units to become idle.
(Some will remain blocked or waiting; these will be fixed in the post deploy steps.)

### Post Deployment

The post deployment steps that is output from `./generate-bundle.sh`
need to be run with a particular order and specific arguments.

First, unseal the vault:

```
./tools/vault-unseal-and-authorise.sh
```

Then the configure script, passing `serverstack` argument as the profile.
For deployments on other OpenStack underclouds,
see available profiles in `./profiles/`.

Before running this, ensure your `novarc` file for your Serverstack user
is available at `~/novarc`.
If this is not possible, search the scripts for `~/novarc` and
update the path to point to your Serverstack novarc file.

```
./configure serverstack
```

A final optional step is to set up some default rules for the overcloud security groups.
This also demonstrates use of the overcloud `./novarc` file
that extracts the required auth information for the overcloud,
setting the appropriate `OS_*` variables in the environment.
This script only supports bash, and requires the openstack model to be active in juju.

```
source ./novarc
./tools/sec_groups.sh
```

## Use the overcloud!

Now you can source the provided `./novarc`,
and begin using OpenStack tools (such as the cli)
to interact with the deployed overcloud.

A quick first check could be to try listing the services:

```
source ./novarc
openstack service list
```

If all is good, you should see the available services, for example:

```
+----------------------------------+-----------+-----------+
| ID                               | Name      | Type      |
+----------------------------------+-----------+-----------+
| 03806a4a47494deb996e0e9ca20fdb46 | neutron   | network   |
| 10105f7945cd4f98b19830f3fff04432 | glance    | image     |
| 1f369340fed4442e8c3583e7914759eb | cinderv3  | volumev3  |
| 275e96356e3e4777984dd7f0fb43c53f | keystone  | identity  |
| 82fef7a3c42d4f84aa571ef8ca668a8d | placement | placement |
| 880681bae1434f8e9e8a34c436c4645c | nova      | compute   |
+----------------------------------+-----------+-----------+
```

Finally, an example of creating an instance on the overcloud:

```
source ./novarc
# need to create a keypair first; everything else is created in the ./configure step earlier.
openstack keypair create ubuntu-keypair --public-key <(cat YOUR_SSH_PUBLIC_KEY.pub)
openstack server create --flavor m1.tiny --key-name ubuntu-keypair --image cirros --network private test1
```
