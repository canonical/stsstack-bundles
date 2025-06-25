# Deploying Octavia

To deploy Octavia as part of an Openstack deployment just add the `--octavia` overlay. Once deployed there are a few actions that must be taken to configure Octavia before it can be used.

**NOTE**: if you are using OVN as your neutron networking solution, you will need to perform the steps detailed in the [`ovn`](ovn) documentation before continuing

##  Post-deployment configuration

The following will download the Amphora image from (`stsstack`) Swift that corresponds to the deployed release of Openstack and upload it to your Glance.

```console
tools/upload_octavia_amphora_image.sh
```

The following will configure Octavia's TLS certificate and `lb-mgmt` network.

```console
tools/configure_octavia.sh
```

<https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/app-octavia.html>

## Using Octavia

1. Create an instance and security group rules

    ```console
    source novarc
    ./tools/sec_groups.sh &>2 &
    ./tools/instance_launch.sh 1 jammy
    ```

1. Give it a floating IP and ensure it can be pinged (once booted)

    ```console
    ./tools/float_all.sh
    ping __FIP__
    ```

1. Install Apache

    ```console
    ssh __FIP__ -- 'sudo apt update; sudo apt install apache2 -y'
    ```

1. Now create a load balancer adding the VM just created to the LB pool

    ```console
    tools/create_octavia_lb.sh __VM_UUID__
    ```

1. Now check that your load balancer is up and load balancing to port 80 in the VM

    ```console
    lb_vip=$(openstack loadbalancer show lb1 -c vip_address -f value)
    lb_fip=$(openstack floating ip list --fixed-ip-address ${lb_vip} -f value -c floating_ip_address)
    nc -vz ${lb_fip} 80
    ```
