# STSStack Bundles

This repository contains a set of bundles that leverage Juju bundle overlays to
allow generating complex deployments from a number of options using a single
command. These bundles are designed for use with the Juju OpenStack provider.

The top level directory contains a set of *modules*, each of which has a
generate-bundle.sh script which you can use to create a deployment from a
number of options.

NOTE: see `generate-bundle.sh --help` for option info about using that
particular module.

The basic usage is as follows:

* give your deployment a name with (`--name`)
* create a Juju model using the given name or use existing one
* add one or more feature overlays depending on what you need (see
  `--list-overlays`)
* resources are stored under a named directory so as to be able to avoid
  collisions and replay later (`--replay`)
* immediate deploy (`--run`) or save for later

Example:

Say you want to deploy OpenStack using the Caracal release on Jammy and you want
to enable ceph and heat with keystone in HA:

```console
$ cd openstack
$ ./generate-bundle.sh --name mytest -r caracal --ceph --heat --keystone-ha
Creating Juju model mytest

Created jammy-caracal bundle and overlays:
  + openstack/glance.yaml
  + openstack/keystone.yaml
  + ceph/ceph.yaml
  + openstack/openstack-ceph.yaml
  + ceph/ceph-juju-storage.yaml
  + openstack/heat.yaml
  + openstack/keystone-ha.yaml
  + openstack/neutron-ovn.yaml
  + vault.yaml
  + openstack/vault-openstack-secrets.yaml
  + openstack/vault-openstack-certificates.yaml
  + openstack/vault-openstack-certificates-heat.yaml
  + openstack/vault-openstack-certificates-placement.yaml
  + ceph/vault-ceph.yaml
  + openstack/neutron-ml2dns.yaml
  + mysql-innodb-cluster.yaml
  + mysql-innodb-cluster-router.yaml
  + openstack/placement.yaml

Command to deploy:
juju deploy     /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/openstack.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/glance.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/keystone.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/ceph/ceph.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/openstack-ceph.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/ceph/ceph-juju-storage.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/heat.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/keystone-ha.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/neutron-ovn.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/vault.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-secrets.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates-heat.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates-placement.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/ceph/vault-ceph.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/neutron-ml2dns.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/mysql-innodb-cluster.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/mysql-innodb-cluster-router.yaml --overlay /home/user1/git/canonical/stsstack-bundles/openstack/b/mytest/o/openstack/placement.yaml 
 

Post-Deployment Info/Actions:

[common]
  - run ./tools/vault-unseal-and-authorise.sh
  - run ./configure to initialise your deployment
  - source novarc
  - add rules to default security group: ./tools/sec_groups.sh
```

Note that the generated bundles and overlays are stored under a directory with
the name you specified. You can now either (1) copy the command line above and
execute it, or (2) add `--run` to `./generate-bundle.sh` to automatically
execute the mode, or (3) source `b/mytest/command`.

If you need to manually edit a bundle/overlay prior to deploying you can skip
the `--run` argument and either manually run the deploy command once you have
made your changes or alternatively re-run with `--replay` (which will prevent
the files from being re-generated).

Note that an OpenStack deployment will almost certainly require the `openstack`
command line client. At the time of this writing, installing `openstackclients`
via snap is not fully supported. Instead, please install the client via package:

```console
sudo apt install python3-openstackclient python3-neutronclient
```
