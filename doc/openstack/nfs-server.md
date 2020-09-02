# Deploying nfs-server

The stsstack-bundles support deploying nfs-server as an overlay which can be
used for the usecases where nfs server is required. Some of the use cases this
will be helpful
* cinder-backup configured to nfs backend [1]
* deployment with trilio services [2] [3]

Generate the cloud yaml via ./generate-bundle.sh adding --nfs-server overlay
A new unit nfs-server-test-fixture/0 will be deployed which runs nfs-server.
An additional disk of storage size 40 GB is attached to the unit.

NFS export directory is configured at the path /srv/testing

```
# cat /etc/exports 
# Test export with no permission restrictures
/srv/testing *(rw,sync,no_root_squash)
```

The NFS Share mount path on the client side can be specified as
<IP of nfs-server-test-fixture/0 unit>:/src/testing

Example:
```
juju config trilio-wlm nfs-shares=10.5.1.170:/srv/testing
```

[1] https://docs.openstack.org/cinder/latest/configuration/block-storage/backup/nfs-backup-driver.html
[2] https://jaas.ai/u/openstack-charmers/trilio-wlm/3#charm-config-nfs-shares
[3] https://jaas.ai/u/openstack-charmers/trilio-data-mover/2#charm-config-nfs-shares
