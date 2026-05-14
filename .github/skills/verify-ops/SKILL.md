---
description: Walks the user through verifying and performing infrastructure operations (upgrades, refreshes, day-2 cloud ops, troubleshooting) with safety checks. Covers Juju and OpenStack today; extensible to other systems. Use when the user says "/verify-ops", "upgrade juju", "upgrade controller", "upgrade model", "refresh charm", "series upgrade", "openstack upgrade", "post-deploy setup", "day-2 ops", or asks for a guided ops walkthrough.
---

## Instructions

This skill is an interactive guide for infrastructure operations. Two non-negotiable rules apply to **every** subsystem:

1. Show every command to the user before running it, and wait for an explicit "go".
2. Always run read-only pre-flight checks first; never combine destructive steps in one shell call.

### Step A — Identify the subsystem

Ask the user which infrastructure system the operation targets:

1. **Juju** (client / controller / model / charms / series upgrade) — see "Juju operations".
2. **OpenStack** (post-deploy setup / service upgrades / day-2 cloud ops / troubleshooting) — see "OpenStack operations".
3. *(future)* Ceph, Kubernetes, COS, etc. — not yet covered. If the user asks for one of these, say so and offer to either fall back to general advice or extend this skill.

Then jump to the matching section. If the operation spans both (e.g. upgrading OpenStack services is charm-driven via Juju), start in the more specific section and link back as needed.

---

## Juju operations

### J-0 — Detect Juju version

Before anything else, run:

```
juju version
```

Parse the major version and remember it for the rest of the session. The only upgrade command that was renamed between major versions is the series upgrade:

- **2.9.x** → `juju upgrade-series <machine> prepare|complete`
- **3.x / 4.x** → `juju upgrade-machine <machine> prepare|complete`

`upgrade-controller`, `upgrade-model`, and `refresh` are the same across 2.9 and 3.x.

If the client and controller versions differ in major version, surface that to the user before proceeding — cross-major operations have extra constraints (e.g. you may need to `juju migrate` first).

### J-1 — Ask which operation

Ask the user which of the following they want to do (one at a time):

1. **Upgrade juju client** (the `juju` CLI on this machine)
2. **Upgrade controller**
3. **Upgrade model(s)**
4. **Upgrade charm(s)** (`juju refresh`)
5. **Series upgrade machines** (e.g. focal → jammy)

If unsure, remind them of the canonical order: **client → controller → model → charms → series**. Skipping order can leave a controller unable to manage newer models, or charms incompatible with the model version.

### J-2 — Pre-flight checks (always run these first)

Run these read-only commands and show output before any change:

```
juju version
juju show-controller
juju models
juju status --format=short
```

Confirm with the user:
- Which controller / model is the target
- Current vs. desired version
- Whether a recent backup exists (controller upgrades especially)

### J-3 — Run the operation

Show the exact command, explain what it will do, and wait for explicit "go" before running.

**Client:**
```
sudo snap refresh juju --channel=<track>/stable
```

**Controller:**
```
juju upgrade-controller --agent-version=<X.Y.Z>
```
Notes: client must be ≥ controller version. For major bumps, check the Juju release notes for migration steps.

**Model:**
```
juju upgrade-model --agent-version=<X.Y.Z> -m <model>
```
Notes: model version cannot exceed controller version.

**Charm:**
```
juju refresh <app> [--channel=<track>/<risk>] [--revision=<n>]
```
Notes: prefer `--channel` over pinning revisions unless the user has a reason. Watch `juju status` for `workload` and `agent` going back to active/idle.

**Series upgrade (per machine):**

The command name depends on the Juju version detected in J-0.

*Juju 3.x / 4.x:*
```
juju upgrade-machine <machine> prepare <new-series> --yes
# then on the machine itself:
sudo do-release-upgrade
# back on the workstation:
juju upgrade-machine <machine> complete
```

*Juju 2.9.x:*
```
juju upgrade-series <machine> prepare <new-series> --yes
# then on the machine itself:
sudo do-release-upgrade
# back on the workstation:
juju upgrade-series <machine> complete
```

Notes: prepare blocks new units; complete must run only after the OS upgrade succeeds and the machine is rebooted. For HA controllers and DB units, coordinate one machine at a time.

### J-4 — Verify

After each operation, re-run `juju status` and confirm:
- Units back to `active/idle`
- No `error` or `blocked` states
- Agent versions match expectations

### Juju safety rules

- Never run an upgrade command without the user saying go.
- Never combine multiple destructive steps in one shell call.
- If `juju status` shows units in `error` or `blocked` before upgrade, stop and surface that first.
- For production controllers, ask whether a backup was taken in the last 24h before `upgrade-controller`.

---

## OpenStack operations

This section assumes the OpenStack cloud was deployed via charms in this repo's pattern (`stsstack-bundles`-style). Many helper scripts live under `openstack/tools/` and `openstack/bin/` — prefer those over hand-rolled commands when they exist.

### O-0 — Source credentials and identify the cloud

Before any `openstack` CLI call, source credentials. In this repo:

```
source openstack/novarc
# or for v3 domain-scoped:
source openstack/novarcv3_domain
```

If credentials don't exist yet, regenerate them:

```
openstack/tools/construct_novarc.sh
```

Sanity check that the environment is loaded and reachable:

```
openstack catalog list
openstack service list
```

If either fails, do not proceed — surface the auth/endpoint error to the user and stop.

### O-1 — Ask which operation category

Ask the user which of the following they want to do:

1. **Post-deploy setup** — get a freshly deployed cloud usable (CA install, image upload, networks, security groups, Octavia, Vault unseal).
2. **Service upgrade** — bump OpenStack services (Nova, Neutron, Keystone, …). Charm-driven; this redirects into the Juju section for the `juju refresh` work, then comes back here for the `openstack-upgrade` action.
3. **Day-2 cloud ops** — project/user/quota mgmt, network/router ops, image lifecycle, security groups, floating IPs.
4. **Troubleshooting & validation** — service/endpoint health, instance launch test, Octavia LB checks.

### O-2 — Pre-flight (always)

Read-only checks before any change:

```
juju status --format=short        # underlying charms healthy?
openstack catalog list
openstack service list
openstack endpoint list
```

Confirm with the user:
- Which cloud / region / project is targeted (the env vars `OS_AUTH_URL`, `OS_PROJECT_NAME`, `OS_REGION_NAME`).
- For destructive ops: whether the target resources are in a non-production project.

### O-3 — Run the operation

Show every command before running and wait for explicit "go".

**Post-deploy setup** (typical order, skip any not needed):

```
openstack/tools/install_local_ca.sh                       # trust local CA (if Vault/PKI)
openstack/tools/vault-unseal-and-authorise.sh             # only if Vault is in the bundle
openstack/tools/upload_image.sh <series>                  # cloud images to Glance
openstack/bin/neutron-ext-net -g <gateway> -c <cidr> ...  # external network
openstack/bin/neutron-project-net                          # project network
openstack/tools/sec_groups.sh                              # baseline SG rules
openstack/tools/configure_octavia.sh                       # if octavia overlay
openstack/tools/upload_octavia_amphora_image.sh
openstack/tools/create_octavia_lb.sh
openstack/tools/create_nova_az_aggregates.sh               # AZs/aggregates if needed
openstack/tools/create_project.sh <name>                   # extra tenants
```
Notes: each script is independent — run them one at a time and confirm with `openstack` CLI afterwards. Read the script before running if you're unsure what it does.

**Service upgrade** (charm-driven):

1. Hand off to the Juju section J-1 → option 4 (charm refresh) to do `juju refresh <app> --channel=<new-channel>`.
2. After refresh, for components that need data migrations, run the upgrade action on the leader:
   ```
   juju run-action --wait <app>/leader openstack-upgrade
   ```
   (Action name and availability vary by charm — check `juju actions <app>` first.)
3. Return here for O-4 validation against the new version.

**Day-2 cloud ops** — use the `openstack` CLI. Typical commands:

```
# Projects / users / quotas
openstack project create <name> --domain <domain>
openstack user create <user> --project <project> --password-prompt
openstack quota set --instances <n> --cores <n> --ram <MB> <project>

# Networks / routers
openstack network create <name>
openstack subnet create --network <net> --subnet-range <cidr> <name>
openstack router create <name>
openstack router add subnet <router> <subnet>

# Images
openstack image create --file <path> --disk-format qcow2 --container-format bare <name>
openstack image delete <id>

# Security groups
openstack security group rule create --proto tcp --dst-port 22 <sg>
```
Always show the exact command and target object, and confirm before delete/quota-change.

**Troubleshooting & validation:**

```
openstack catalog list                # endpoints registered?
openstack endpoint list               # public/internal/admin URLs correct?
openstack service list                # all services enabled?
openstack compute service list        # nova-compute hosts up?
openstack network agent list          # neutron agents alive?
openstack volume service list         # cinder services healthy?
openstack/tools/instance_launch.sh    # smoke test: boot an instance
openstack loadbalancer list           # octavia LBs (if applicable)
openstack loadbalancer status show <lb>
```
For deeper issues, drop into the relevant unit with `juju ssh <app>/<n>` and check service logs.

### O-4 — Verify

After each operation, re-confirm health:
- `openstack catalog list` and `openstack service list` show no missing services.
- `juju status` shows `active/idle` for the affected charm(s).
- For data-plane changes (networks, security groups), launch a tiny test instance and confirm reachability.

### OpenStack safety rules

- Always source credentials explicitly; never assume `OS_*` env vars are correct from a prior shell.
- Never run a script under `openstack/tools/` blind — open and read it first, especially `delete_*` and anything touching Octavia/Vault.
- For delete/quota commands, name the exact target and confirm before running.
- Prefer the repo's helper scripts over hand-rolled CLI when both exist — they encode known-good defaults for this stack.
- Production clouds: refuse destructive ops unless the user explicitly confirms the cloud name and region.

---

## Other subsystems

Not yet implemented. When extending this skill, follow the same pattern: detect environment → ask which operation → pre-flight → run → verify → safety rules.
