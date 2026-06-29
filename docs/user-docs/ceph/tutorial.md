# Tutorial for deploying on `serverstack`

`Serverstack` is an internal deployment of OpenStack, but these instructions may help for deploying on top of any OpenStack undercloud.

## Prerequisites

Be sure to read the [prerequisites](https://canonical-stsstack-bundles.readthedocs-hosted.com/en/latest/user-docs/prerequisites/) before proceeding to
ensure a working environment.

## Deploying

This deployment will make use of 3 openstack machines in a hyperconverged configuration.

Create the juju model.

```bash
juju add-model ceph prodstack
```

Set the openstack flavor to use for the hyperconverged instances.

```bash
juju set-model-constraints instance-type="staging-cpu2-ram4-disk50"
```

Change directory into *ceph* for this deployment.

```bash
cd stsstack-bundles/ceph/
```

Generate and run the bundle. Note that `./configure` does not do anything afterwards and can be skipped.

```bash
./generate-bundle.sh --name ceph:prodstack -s jammy --num-osds-per-host 1 --run --hyperconverged --default-binding alpha
```

The result should look like the following.

```bash
Model  Controller  Cloud/Region          Version  SLA          Timestamp
ceph   controller  prodstack/prodstack6  3.6.14   unsupported  23:46:19Z

App                    Version  Status  Scale  Charm                 Channel      Rev  Exposed  Message
ceph-mon               17.2.9   active      1  ceph-mon              quincy/edge  493  no       Unit is ready and clustered
ceph-osd               17.2.9   active      3  ceph-osd              quincy/edge  863  no       Unit is ready (1 OSD)
glance                 24.2.1   active      1  glance                yoga/stable  620  no       Unit is ready
glance-mysql-router    8.0.45   active      1  mysql-router          8.0/stable   257  no       Unit is ready
keystone               21.0.1   active      1  keystone              yoga/stable  689  no       Application Ready
keystone-mysql-router  8.0.45   active      1  mysql-router          8.0/stable   257  no       Unit is ready
mysql                  8.0.45   active      3  mysql-innodb-cluster  8.0/stable   159  no       Unit is ready: Mode: R/O, Cluster is ONLINE and can tolerate up to ONE failure.

Unit                        Workload  Agent  Machine  Public address   Ports     Message
ceph-mon/0*                 active    idle   0/lxd/0  252.119.37.138             Unit is ready and clustered
ceph-osd/0*                 active    idle   1        10.149.12.87               Unit is ready (1 OSD)
ceph-osd/1                  active    idle   2        10.149.12.116              Unit is ready (1 OSD)
ceph-osd/2                  active    idle   0        10.149.12.59               Unit is ready (1 OSD)
glance/0*                   active    idle   2/lxd/0  252.232.4.157    9292/tcp  Unit is ready
  glance-mysql-router/0*    active    idle            252.232.4.157              Unit is ready
keystone/0*                 active    idle   0/lxd/1  252.119.221.251  5000/tcp  Unit is ready
  keystone-mysql-router/0*  active    idle            252.119.221.251            Unit is ready
mysql/0                     active    idle   0/lxd/2  252.118.240.247            Unit is ready: Mode: R/O, Cluster is ONLINE and can tolerate up to ONE failure.
mysql/1                     active    idle   2/lxd/1  252.232.21.111             Unit is ready: Mode: R/O, Cluster is ONLINE and can tolerate up to ONE failure.
mysql/2*                    active    idle   1/lxd/0  252.174.8.83               Unit is ready: Mode: R/W, Cluster is ONLINE and can tolerate up to ONE failure.

Machine  State    Address          Inst id                               Base          AZ                   Message
0        started  10.149.12.59     2d6f7927-34f7-4f3f-a4dc-bc38ae540e65  ubuntu@22.04  availability-zone-2  ACTIVE
0/lxd/0  started  252.119.37.138   juju-43d87e-0-lxd-0                   ubuntu@22.04  availability-zone-2  Container started
0/lxd/1  started  252.119.221.251  juju-43d87e-0-lxd-1                   ubuntu@22.04  availability-zone-2  Container started
0/lxd/2  started  252.118.240.247  juju-43d87e-0-lxd-2                   ubuntu@22.04  availability-zone-2  Container started
1        started  10.149.12.87     ca60c81d-60ac-4824-9767-ec566d404985  ubuntu@22.04  availability-zone-1  ACTIVE
1/lxd/0  started  252.174.8.83     juju-43d87e-1-lxd-0                   ubuntu@22.04  availability-zone-1  Container started
2        started  10.149.12.116    2c5ea1a0-47ee-4bb1-b0c9-e00b005f830b  ubuntu@22.04  availability-zone-3  ACTIVE
2/lxd/0  started  252.232.4.157    juju-43d87e-2-lxd-0                   ubuntu@22.04  availability-zone-3  Container started
2/lxd/1  started  252.232.21.111   juju-43d87e-2-lxd-1                   ubuntu@22.04  availability-zone-3  Container started
```
