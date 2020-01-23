# Deplying nova-network using the Openstack charms

Nova-network was the first implementation of networking in Openstack and was replaced by Neutron (originally named "Quantum") around the Essex release. While verybody switched to using Neutron, nova-network was not fully deprecated until the Mitaka release and as such is still technically supported on Xenial. It is worth noting that there are no longer any known users of this service though. Deploying it requires a few tweaks to the charms. Here is a guide on how to deploy and configure it:

See https://docs.google.com/document/d/1_U4IVvcYBiTc34qRR2MaPLE-N7Ths4LmnhmEBocUSEA/edit
