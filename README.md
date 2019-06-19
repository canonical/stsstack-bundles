# STSStack Bundles

This repository contains a set of bundles that leverage Juju bundle overlays to allow generating complex deployments from a number of options using a single command. These bundles are designed for use with a Juju Openstack provider.

If you look in the top level directory you will see a set of modules. If you then go into these you will find a generate-bundle.sh tool with which you can create a deployment from a number of options.

NOTE: see generate-bundle.sh --help for option info about using that particular module.

The basic usage is as follows:

   * give your deployment a name with (--name)
   * create a Juju model using the given name (--create-model) or use existing one or default
   * add a bunch of feature overlays depending on what you need (see --list-overlays)
   * resources are stored under a named directory so as to be able to avoid collisions and replay later (--replay)
   * immediate deploy (--run) or save for later

Example:

Say you want to deploy Openstack using the Stein release on Bionic and you want to enable ceph and heat with keystone in HA:

```
cd openstack; $ ./generate-bundle.sh --name mytest --create-model -r stein --ceph --heat --keystone-ha
```

This will give you output like:

```
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

Note that the generated bundles and overlays are stored under a directory with the name you specified. You can now either copy the command and execute it or add --run to automatically execute it.

If you need to manually edit a bundle/overlay prior to deploying you can skip the --run argument and either manually run the deploy command once you have made your changes or alternatively re-run with --run --replay (which will prevent the files from being re-generated).
