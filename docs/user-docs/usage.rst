Usage
=====

Using ``stsstack-bundles`` involves generating a bundle and overlays, deploying them then performing some post-deployment actions.

As an example, let's say you want to deploy OpenStack using the Caracal release on Jammy and you want to enable Ceph and heat with Keystone in HA:

.. code-block:: console

    $ cd openstack
    $ ./generate-bundle.sh --name mytest -r caracal --ceph --heat --keystone-ha
    Creating Juju model mytest
    add-model mytest
    model-config -m mytest default-series=jammy

    model-config test-mode=true
    set-model-constraints root-disk-source=volume root-disk=20G
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
    juju deploy /home/ubuntu/stsstack-bundles/openstack/b/mytest/openstack.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/glance.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/keystone.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/ceph/ceph.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/openstack-ceph.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/ceph/ceph-juju-storage.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/heat.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/keystone-ha.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/neutron-ovn.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/vault.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-secrets.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates-heat.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/vault-openstack-certificates-placement.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/ceph/vault-ceph.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/neutron-ml2dns.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/mysql-innodb-cluster.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/mysql-innodb-cluster-router.yaml\
       --overlay /home/ubuntu/stsstack-bundles/openstack/b/mytest/o/openstack/placement.yaml 
     

    Post-Deployment Info/Actions:

    [common]
      - run ./tools/vault-unseal-and-authorise.sh
      - run ./configure to initialise your deployment
      - source novarc
      - add rules to default security group: ./tools/sec_groups.sh

If you need to manually edit a bundle/overlay prior to deploying you can skip the ``--run`` argument and either manually run the deploy command once you have made your changes or alternatively re-run with ``--replay`` (which will prevent the files from being re-generated).

Note that an OpenStack deployment will almost certainly require the OpenStack command line client. At the time of this writing, installing ``openstackclients`` via ``snap`` is not fully supported. Instead, please install the client via package:

.. code-block:: console

    sudo apt install python3-openstackclient python3-neutronclient
