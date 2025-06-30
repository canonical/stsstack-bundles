# How to add more OSDs to your Ceph cluster

When you deploy Ceph with `stsstack-bundles` it is using [Juju storage](https://jaas.ai/docs/storage) to create disks and attach them to the `ceph-osd` machines to be used as OSD devices. For example, the following adds one 10G OSD to each unit:

```yaml
applications:
  ceph-osd:
    charm: __CHARM_STORE____CHARM_CS_NS____CHARM_CH_PREFIX__ceph-osd
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

**NOTE**: these changes only apply at deploy time, if you want to add more disks post-deployment you will need to create volumes in OpenStack and attach them to the VMs running `ceph-osd` then use the `add-disk` action to format them as OSDs.
