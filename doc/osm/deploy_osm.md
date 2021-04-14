# Steps to deploy OSM

0. Pre-requisite:
Deployed kubernetes cluster
 
1. Generate OSM bundle

```
generate-bundle.sh -n <model_name>:<cloud_name> --k8s-model <k8s_model_name>
```

2. Install OSMClient

```
sudo snap install osmclient --beta
/snap/bin/osmclient.osm --hostname <nbi-k8s service loadbalancer ip> ns-list
```

3. Add VIM to OSM
Refer section 'Add Microstack as VIM' in https://jaas.ai/tutorials/charmed-osm-get-started#5-setting-up-charmed-osm

4. Onboarding VNFs
Refer https://jaas.ai/tutorials/charmed-osm-get-started#6-onboarding-vnfs
