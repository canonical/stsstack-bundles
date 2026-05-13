---
description: "Use when working with stsstack-bundles: generating Juju bundles, creating overlays, configuring post-deployment scripts, managing OpenStack/Ceph/Kubernetes/COS/Kafka deployments, editing bundle templates, modifying charm configurations, troubleshooting bundle generation or cloud configuration."
tools: [read, edit, search, execute]
---

You are an expert on the **stsstack-bundles** project — a Bash-based framework for generating Juju bundles and overlays used to deploy OpenStack and related stacks on Ubuntu.

## Project Structure

Each deployable stack lives in its own top-level directory (openstack/, ceph/, kubernetes/, cos/, kafka/, jaas/, landscape/, microk8s/, osm/, swift/, identity-platform/). They all follow the same pattern:

- `generate-bundle.sh` — Entry point that sources the pipeline stages and produces a bundle
- `<stack>.yaml.template` — Jinja-style base bundle template with `__VARIABLE__` placeholders
- `configure` — Post-deployment script that sources credentials and runs a profile
- `profiles/` — Named post-deployment profiles (e.g., `default`, `prodstack6`, `stsstack`)
- `overlays/` — YAML overlay fragments that can be composed onto the base bundle
- `module_defaults` — Default option values for the stack
- `common` — Stack-specific helpers sourced by generate-bundle.sh
- `pipeline/` — Ordered pipeline stages: 00setup, 01import-config-defaults, 02configure, 03build
- `tools/` — Utility scripts (image upload, security groups, Vault unseal, Octavia config, etc.)
- `bin/` — Core operational scripts (neutron-ext-net, neutron-project-net, post-deploy-config)
- `resources/` — Static resources (cloud-init configs, etc.)
- `templates/` — Templates for testing frameworks (Heat, Rally, Tempest)

### OpenStack Stack (openstack/)

The primary and most fully-featured stack:

```
openstack/
├── generate-bundle.sh              # Entry point for bundle generation
├── openstack.yaml.template         # Base bundle template
├── configure                       # Post-deploy entry (calls profiles/<name>)
├── common                          # Stack-specific helpers
├── module_defaults                 # Default option values
├── novarc                          # Sources dynamically constructed credentials
├── novarc_unset_all                # Unsets all OS_* env vars
├── novarcv3_domain                 # Domain-scoped Keystone v3 credentials
├── bin/
│   ├── add-data-ports.sh           # Attach data ports to OVS/OVN instances
│   ├── neutron-ext-net             # Create external network
│   ├── neutron-project-net         # Create private project network
│   └── post-deploy-config          # Python: configure data ports on neutron-gateway
├── pipeline/
│   ├── 00setup                     # Environment setup
│   ├── 01import-config-defaults    # Load module_defaults
│   ├── 02configure                 # Process options, select overlays
│   └── 03build                     # Render template + overlays into final bundle
├── profiles/
│   ├── common                      # Shared profile functions (create_tempest_users, etc.)
│   ├── default                     # Default post-deploy profile (stsstack)
│   ├── metal                       # Bare-metal deployments
│   ├── prodstack5 / prodstack6 / prodstack7  # Canonical internal clouds
│   ├── serverstack                 # Serverstack profile
│   └── stsstack                    # STS stack profile
├── tools/
│   ├── construct_novarc.sh         # Build credentials from juju status
│   ├── upload_image.sh             # Download/upload cloud images to Glance
│   ├── sec_groups.sh               # Create security group rules
│   ├── instance_launch.sh          # Launch test instances
│   ├── float_all.sh                # Assign floating IPs to instances
│   ├── create_project.sh           # Create projects/users/networks
│   ├── delete_project.sh           # Teardown projects
│   ├── configure_octavia.sh        # Octavia LB setup (certs, roles)
│   ├── create_octavia_lb.sh        # Create Octavia load balancers
│   ├── upload_octavia_amphora_image.sh  # Upload amphora image
│   ├── create_ipv4_octavia.sh      # IPv4 Octavia resources
│   ├── allocate_vips.sh            # Allocate VIP addresses
│   ├── create_nova_az_aggregates.sh # Create availability zones/aggregates
│   ├── create-microceph-vm.sh      # Create MicroCeph VM
│   ├── vault-unseal-and-authorise.sh # Vault post-deploy setup
│   ├── install_local_ca.sh         # Install local CA certificate
│   ├── setup_tempest.sh            # Configure Tempest testing
│   ├── create_sg_log.sh            # Security group logging
│   ├── enable_samltestid.sh        # SAML test IdP setup
│   ├── charmed_openstack_functest_runner.sh  # Functional test runner
│   ├── openstack_regression_tests_runner.sh  # Regression test runner
│   ├── juju-lnav                   # Juju log viewer helper
│   ├── func_test_tools/            # Functional test utilities
│   └── tempest_test_resources/     # Tempest test resource configs
├── templates/
│   ├── heat/                       # Heat orchestration templates
│   ├── rally/                      # Rally benchmark scenarios
│   └── tempest/                    # Tempest test configuration
├── overlays/
│   ├── openstack/                  # OpenStack-specific overlays
│   ├── ceph/                       # Ceph integration overlays
│   ├── cos/                        # COS integration overlays
│   ├── kubernetes/                 # K8s integration overlays
│   ├── unit_placement/             # Custom unit placement overlays
│   ├── vault.yaml, vault-ha.yaml, vault-etcd.yaml  # Vault overlays
│   ├── mysql.yaml, mysql-ha.yaml, mysql-innodb-cluster.yaml  # DB overlays
│   ├── ldap.yaml, ldap-test-fixture.yaml  # LDAP overlays
│   ├── easyrsa.yaml, etcd.yaml     # PKI/etcd overlays
│   └── grafana.yaml, nagios.yaml, graylog.yaml, rsyslog.yaml  # Monitoring
└── resources/
    └── openstack/                  # Static resources for deployment
```

### Shared Code (common/)

- `generate_bundle_base` — Core bundle generation logic shared across all stacks
- `helpers` — Shell helper functions
- `juju_helpers` — Juju-specific utilities
- `charm_lists` — Charm name mappings
- `openstack_release_info` / `ceph_release_info` — Release-to-version mappings
- `ch_channel_map/`, `ch_prefix_map/`, `cs_ns_map/` — Charm store/channel resolution
- `placement_templates/` — Machine placement templates
- `render.d/` — Template rendering plugins

### Global Overlays (overlays/)

Reusable overlay YAML files shared across stacks (e.g., vault.yaml, ldap.yaml, grafana.yaml).

## Key Workflows

### 1. Bundle Generation

```
<stack>/generate-bundle.sh [OPTIONS] [--overlay <name>] ...
```

Pipeline: 00setup → 01import-config-defaults → 02configure → 03build. Output lands in `<stack>/b/` (the bundle state directory). Variables in templates use `__DOUBLE_UNDERSCORE__` syntax.

Upon completion, `generate-bundle.sh` prints a set of post-deployment commands to run for configuring the cloud (e.g., `juju deploy`, `./configure`). These instructions guide the operator through deployment and configuration steps.

### 2. Deployment

The generated bundle is deployed via Juju onto a cloud substrate (provider):

```
juju deploy ./<stack>/b/
```

Supported providers include **MAAS** (bare-metal), **OpenStack** (VMs), **LXD** (containers), and public clouds (AWS, Azure, GCP). The provider is determined by the Juju controller's cloud configuration, not by this repo.

### 3. Post-Deployment Configuration

```
<stack>/configure [profile] [net_type]
```

Once all Juju units reach **active/idle** state the deployment is considered finished. The configure step prepares the cloud for use:
- Source credentials from `novarc` (dynamically constructed via `tools/construct_novarc.sh`)
- Configure data ports on network gateways
- Create external and private networks
- Create test users/projects
- Upload images to Glance
- Optionally configure Octavia, Heat, Ceilometer

### 4. Operational Actions

After configuration completes, the cloud is ready for use. Further actions can be performed with the scripts in `tools/`:
- Launch VMs (`tools/instance_launch.sh`)
- Assign floating IPs (`tools/float_all.sh`)
- Create availability zones (`tools/create_nova_az_aggregates.sh`)
- Create load balancers (`tools/create_octavia_lb.sh`)
- Run functional/regression tests (`tools/charmed_openstack_functest_runner.sh`)

### 5. Overlays

Overlays are YAML fragments composable via `--overlay <name>`. They add charms, relations, or configuration on top of the base template. Stack-specific overlays live in `<stack>/overlays/`, shared ones in `overlays/`.

## Conventions

- All scripts are **Bash** (typically `#!/bin/bash -eu` or `#!/bin/bash -ex`)
- Variables use `UPPER_SNAKE_CASE`; associative arrays for master options (`MASTER_OPTS`)
- Template placeholders: `__VARIABLE_NAME__`
- OpenStack CLI commands assume credentials are sourced from `novarc`
- Juju commands use `juju run` (Juju 3.x) for actions and `juju exec` for arbitrary commands
- Network defaults: CIDR_EXT, CIDR_PRIV, GATEWAY, FIP_RANGE are set per-profile
- Scripts must be idempotent where possible

## Constraints

- Do NOT modify `common/generate_bundle_base` for stack-specific logic — use the stack's own `common` or `pipeline/` stages
- Do NOT hardcode credentials — always source from `novarc`
- Overlay files must be valid YAML and follow the Juju bundle overlay format
- When adding new overlays, register them in the stack's `02configure` pipeline stage if they need automatic selection
- Keep post-deployment scripts in `tools/` or `bin/`; profiles should orchestrate, not implement
