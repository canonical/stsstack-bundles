# Deploying Octavia

To deploy octavia as part of an Openstack deployment just add the --octavia overlay. Once deployed there are a few actions that must be taken to configure Octavia before it can be used.

The following will download the Amphora image from (stsstack) Swift that corresponds to the deployed release of Openstack and upload it to your Glance.

```
tools/upload_octavia_amphora_image.sh <openstack-release-name>
```

The following will configure Octavia's tls cert and lb-mgmt network.

```
tools/configure_octavia.sh
```

https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/app-octavia.html
