# Steps to deploy OSM

1. Pre-requisite:

    Deployed Kubernetes cluster

1. Generate OSM bundle

    ```console
    generate-bundle.sh -n <model_name>:<cloud_name> --k8s-model <k8s_model_name>
    ```

1. Install OSMClient

    ```console
    sudo snap install osmclient --beta
    /snap/bin/osmclient.osm --hostname <nbi-k8s service loadbalancer ip> ns-list
    ```

1. Add VIM to OSM

    Refer section 'Add Microstack as VIM' in `https://jaas.ai/tutorials/charmed-osm-get-started#5-setting-up-charmed-osm`

1. Onboarding VNFs

    Refer `https://jaas.ai/tutorials/charmed-osm-get-started#6-onboarding-vnfs`
