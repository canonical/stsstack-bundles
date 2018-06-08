Once deployed you will need to manually do the following for each ceph-osd unit:

   juju run-action ceph-osd/<unit> zap-disk devices='/dev/vdb' i-really-mean-it=true --wait
   juju run-action ceph-osd/<unit> add-disk osd-devices='/dev/vdb' --wait
