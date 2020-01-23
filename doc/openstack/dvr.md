# Deploying Neutron DVR

The stsstack-bundles support multiple forms of dvr and whichever you use will require running the following post-deployment in order to add an extra port to your compute hosts for the external network connectivity:

```
bin/add-ports.sh neutron-openvswitch
```
