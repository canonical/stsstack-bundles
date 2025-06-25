# Deploying NFS-server

The `stsstack-bundles` support deploying `nfs-server` as an overlay which can be used for the use cases where `nfs-server` is required. Some of the use cases this will be helpful

* cinder-backup configured to NFS backend [[1]](https://docs.openstack.org/cinder/latest/configuration/block-storage/backup/nfs-backup-driver.html)
* deployment with `trilio` services [[2]](https://charmhub.io/trilio-wlm/configurations#nfs-shares) [[3]](https://charmhub.io/trilio-data-mover/configurations#nfs-shares)

Generate the cloud bundle via `./generate-bundle.sh adding --nfs-server` overlay. A new unit `nfs-server-test-fixture/0` will be deployed which runs `nfs-server`. An additional disk of storage size 40 GB is attached to the unit.

NFS export directory is configured at the path `/srv/testing`

```console
# cat /etc/exports 
# Test export with no permission restrictions
/srv/testing *(rw,sync,no_root_squash)
```

The NFS Share mount path on the client side can be specified as `<IP of nfs-server-test-fixture/0 unit>:/srv/testing`

Example:

```console
juju config trilio-wlm nfs-shares=10.5.1.170:/srv/testing
```
