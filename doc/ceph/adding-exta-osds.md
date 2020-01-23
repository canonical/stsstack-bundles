# How to add more OSDs to your Ceph cluster

When you deploy Ceph with stsstack-bundles it is using Juju storage [1] to create disks and attach them to the ceph-osd machines to be used as osd devices. For example, the following add one 10G osd to each unit:

```
applications:
  ceph-osd:
    charm: cs:~openstack-charmers-next/ceph-osd
    num_units: 3
    constraints: mem=1G
    options:
      source: *source
      loglevel: *loglevel
      osd-devices: ''  # must be empty string when using juju storage
    storage:
      osd-devices: cinder,10G,1
```

If you wanted to add more disk just increase from 1 to number you want or if you want to increase size of each disk just set 10G to whatever you need.

NOTE: these changes only apply at deploy time, if you want to add more disks post-deployment you will need to create volumes in Openstack and attach them to the vms running ceph-osd then use the add-disk action to format them as OSDs.

[1] https://jaas.ai/docs/storage
