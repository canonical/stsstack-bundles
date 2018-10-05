the configure script does not yet support adding an extra interface to compute hosts so you can run:

(. ~/novarc; net=`openstack network list| grep ${OS_PROJECT_NAME}_admin_net| awk '{print $2}'`;  juju status nova-compute| grep ACTIVE| awk '{print $4}'| xargs -l -I{} nova interface-attach --net-id $net {})
