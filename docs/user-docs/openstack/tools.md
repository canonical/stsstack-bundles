# Tools

After a successful OpenStack deployment via `./generate-bundle.sh` (see [Usage](../usage.rst)), there are a few scripts in `openstack/tools` that might be helpful.

## `allocate_vips.sh`

Allocate the last 20 IP addresses of the network `subnet_${OS_USERNAME}-psd`, which could be considered for VIPs in OpenStack

### Example

```console
allocate_vips.sh
```

## `charmed_openstack_functest_runner.sh`

Run OpenStack charms functional tests manually in a similar way to how Openstack CI (OSCI) would do it. This tool should be run from within a charm root.

Not all charms use the same versions and dependencies and an attempt is made to cover this here but in some cases needs to be dealt with as a pre-requisite to running the tool. For example some charms need their tests to be run using python 3.8 and others python 3.10. Some tests might require Juju 2.9 and others Juju 3.x - the assumption in this runner is that Juju 3.x is good to use.

### Example

```console
charmed_openstack_functest_runner.sh
```

(configure-octavia-sh)=
## `configure_octavia.sh`

Configures a new Octavia deployment. Assumes that the amphora image has been added to Glance already (see ...).

### Example

```console
configure_octavia.sh
```

## `create_ipv4_octavia.sh`

Configure Octavia deployment to use an `IPv4` `lp-mgmt-net`.

### Example

```console
create_ipv4_octavia.sh
```

## `create_nova_az_aggregates.sh`

Create Nova Aggregates for two sets of `nova-compute` units. The script assumes that the compute hosts are divided into two zones, and that the `nova-compute` application was named according to:

```console
juju deploy nova-compute nova-compute-az1
juju deploy nova-compute nova-compute-az2
```

The script takes all units in each set and creates Nova Aggregates for these.

### Example

```console
create_nova_az_aggregates.sh
```

## `create_octavia_lb.sh`

Create a load balancer with Octavia. This command assumes that Octavia has been properly configured, see [`configure_octavia.sh`](#configure-octavia-sh) and `upload_octavia_amphora_image.sh` for details.

### Example

```console
create_octavia_lb.sh --name lb \
    --member-vm server-1 \
    --provider amphora \
    --protocol TCP \
    --protocol-port 22
```

## `create_project.sh`

Create a new project. The command takes up to three optional arguments:

### Usage

```console
create_project.sh [PROJECT_NAME [USER_DOMAIN [NETWORK_CIDR]]]
```

The script will create the project, create a user in that project, assign `Member`, `load-balancer_observer`, and `load-balancer_member` roles to that user, and create a new routable network.

### Example

```console
create_project.sh new-project
```

## `create_sg_log.sh`

Create logs for security group related events.

### Example

```console
create_sg_log.sh
```

## `create-microceph-vm.sh`

Deploys a MicroCeph VM. See

<https://github.com/canonical/microceph>

and

<https://canonical-microceph.readthedocs-hosted.com/en/latest/>

### Example

Deploy using:

```console
juju add-model microceph
juju deploy --constraints mem=16G --series jammy ubuntu microceph-vm
juju scp openstack/tools/create-microceph-vm.sh microceph-vm/0:
juju ssh microceph-vm/0 -- ./create-microceph-vm.sh
```

After everything is deployed, ceph can be used via the ceph command, *e.g.*

```console
juju ssh microceph-vm/0 -- lxc exec microceph-1 ceph status
```

## `delete_project.sh`

Deletes a project and cleans up any used resources, *e.g.*, servers, networks, load balancers, *etc.*.

### Example

```console
delete_project.sh
```

## `enable_samltestid.sh`

Configures Keystone for federation using the `keystone-saml-mellon` charm.

### Example

```console
enable_samltestid.sh
```

## `float_all.sh`

Give all servers a floating IP.

### Example

```console
float_all.sh
```

## `install_local_ca.sh`

Installs the CA for ssl locally. See [`generate-bundle.sh`](../generate-bundle)

## `instance_launch.sh`

Launch a server.

## `juju-lnav`

Run [`lnav`](https://lnav.org/), a log viewer on multiple units for tracking log traces across services.

### Example

```console
juju-lnav keystone:/var/log/keystone \
    neutron-api:/var/log/neutron \
    nova-cloud-controller:/var/log/nova
```

## `openstack_regression_tests_runner.sh`

Run the OSCI test runner locally.

## `sec_groups.sh`

Add standard rules to the default security group, *e.g.* `TCP/22`, `TCP/80`, *etc.*

### Example

```console
sec_groups.sh
```

## `setup_tempest.sh`

### Example

```console
setup_tempest.sh
```

## `upload_image.sh`

### Example

```console
upload_image.sh
```

## `upload_octavia_amphora_image.sh`

Upload the Octavia Amphora image to Glance.

### Example

```console
upload_octavia_amphora_image.sh
```

## `vault-unseal-and-authorise.sh`

Configure `vault`. Has to be run for new deployments or after restarting the `vault` service.

### Example

```console
vault-unseal-and-authorise.sh
```
