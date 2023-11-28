# STSStack Bundles

This repository contains a set of bundles that leverage Juju bundle overlays to
allow generating complex deployments from a number of options using a single
command. These bundles are designed for use with a Juju Openstack provider.

If you look in the top level directory you will see a set of modules. If you
then go into these you will find a generate-bundle.sh tool with which you can
create a deployment from a number of options.

NOTE: see `generate-bundle.sh --help` for option info about using that
particular module.

The basic usage is as follows:

* give your deployment a name with (`--name`)
* create a Juju model using the given name or use existing one or default
* add a bunch of feature overlays depending on what you need (see
  `--list-overlays`)
* resources are stored under a named directory so as to be able to avoid
  collisions and replay later (`--replay`)
* immediate deploy (`--run`) or save for later

Example:

Say you want to deploy Openstack using the Stein release on Bionic and you want
to enable ceph and heat with keystone in HA:

```console
$ cd openstack
$ ./generate-bundle.sh --name mytest -r stein --ceph --heat --keystone-ha
Creating Juju model mytest
Added 'mytest' model on stsstack/stsstack with credential 'hopem' for user 'admin'

Created bionic-stein bundle and overlays (using dev/next charms):
 + ceph.yaml
 + openstack-ceph.yaml
 + heat.yaml
 + keystone-ha.yaml

Command to deploy:
juju deploy ./b/mytest/openstack.yaml --overlay ./b/mytest/o/ceph.yaml --overlay ./b/mytest/o/openstack-ceph.yaml --overlay ./b/mytest/o/heat.yaml --overlay ./b/mytest/o/keystone-ha.yaml
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
