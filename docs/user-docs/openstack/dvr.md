# Deploying Neutron DVR

The stsstack-bundles support multiple forms of DVR and whichever you use will require running the following post-deployment in order to add an extra port to your compute hosts for the external network connectivity:

```console
bin/add-ports.sh neutron-openvswitch
```
