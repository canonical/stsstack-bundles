---
name: neutron-bundle-gen
description: 'Generate a Neutron/OpenStack bundle generate-bundle.sh command interactively. Use when generating neutron bundles, choosing neutron version, Ubuntu series, UCA release, or building the generate-bundle.sh command for OpenStack/Neutron deployment. Guides user through: Ubuntu version → Neutron version → UCA release selection → final command assembly.'
argument-hint: 'Optional initial parameters, e.g. ubuntu=jammy neutron=24'
---

# Neutron Bundle Generation Workflow

## Purpose
Interactively guide the user to assemble a `./generate-bundle.sh` command for
OpenStack/Neutron deployments by selecting compatible Ubuntu series, Neutron version,
and UCA release, referencing the official [Ubuntu Cloud Archive](https://wiki.ubuntu.com/OpenStack/CloudArchive)
and [Neutron releases](https://releases.openstack.org/teams/neutron.html) pages.

---

## Step 1 — Ask Ubuntu version

Ask the user which Ubuntu LTS release they are targeting. Present the supported options:

| Series name | Version |
|-------------|---------|
| trusty      | 14.04   |
| xenial      | 16.04   |
| bionic      | 18.04   |
| focal       | 20.04   |
| jammy       | 22.04   |
| noble       | 24.04   |

---

## Step 2 — Derive valid Neutron/OpenStack versions for that Ubuntu release

Using the reference table below, look up which OpenStack releases (and thus Neutron
versions) are available for the chosen Ubuntu series, both from the default archive
and via UCA.

### Ubuntu → OpenStack / Neutron availability table

Reference: [wiki.ubuntu.com/OpenStack/CloudArchive](https://wiki.ubuntu.com/OpenStack/CloudArchive) and [releases.openstack.org/teams/neutron.html](https://releases.openstack.org/teams/neutron.html)

| Ubuntu series | OpenStack release | Neutron major | Source       |
|---------------|-------------------|---------------|--------------|
| Noble (24.04) | Epoxy (2025.1)    | 26            | UCA `epoxy`  |
| Noble (24.04) | Dalmatian (2024.2)| 25            | UCA `dalmatian` |
| Noble (24.04) | Caracal (2024.1)  | 24            | distro       |
| Jammy (22.04) | Caracal (2024.1)  | 24            | UCA `caracal`|
| Jammy (22.04) | Bobcat (2023.2)   | 23            | UCA `bobcat` |
| Jammy (22.04) | Antelope (2023.1) | 22            | UCA `antelope`|
| Jammy (22.04) | Zed               | 21            | UCA `zed`    |
| Jammy (22.04) | Yoga              | 20            | distro       |
| Focal (20.04) | Yoga              | 20            | UCA `yoga`   |
| Focal (20.04) | Xena              | 19            | UCA `xena`   |
| Focal (20.04) | Wallaby           | 18            | UCA `wallaby`|
| Focal (20.04) | Ussuri            | 16            | distro       |
| Bionic (18.04)| Ussuri            | 16            | UCA `ussuri` |
| Bionic (18.04)| Train             | 15            | UCA `train`  |
| Bionic (18.04)| Stein             | 14            | UCA `stein`  |
| Bionic (18.04)| Rocky             | 13            | UCA `rocky`  |
| Bionic (18.04)| Queens            | 12            | distro       |
| Xenial (16.04)| Queens            | 12            | UCA `queens` |
| Xenial (16.04)| Mitaka            | 8             | distro       |
| Trusty (14.04)| Mitaka            | 8             | UCA `mitaka` |
| Trusty (14.04)| Icehouse          | (2014.1.x)    | distro       |

### Full Neutron version number → OpenStack release mapping

Reference: [releases.openstack.org/teams/neutron.html](https://releases.openstack.org/teams/neutron.html)

| Neutron major | OpenStack release  |
|---------------|--------------------|
| 28            | Gazpacho (2026.1)  |
| 27            | Flamingo (2025.2)  |
| 26            | Epoxy (2025.1)     |
| 25            | Dalmatian (2024.2) |
| 24            | Caracal (2024.1)   |
| 23            | Bobcat (2023.2)    |
| 22            | Antelope (2023.1)  |
| 21            | Zed                |
| 20            | Yoga               |
| 19            | Xena               |
| 18            | Wallaby            |
| 17            | Victoria           |
| 16            | Ussuri             |
| 15            | Train              |
| 14            | Stein              |
| 13            | Rocky              |
| 12            | Queens             |
| 11            | Pike               |
| 10            | Ocata              |

Present to the user the available Neutron versions (with their OpenStack names and
major version numbers) for the chosen Ubuntu series. Accept either a **major version
number** (e.g. `24`) **or** an **OpenStack release name** (e.g. `Caracal`). Resolve
to a release name and confirm with the user.

---

## Step 3 — List all valid UCA / source options for the chosen combination

Cross-reference the Ubuntu series and resolved OpenStack release name in the table
above. Collect all matching rows.

For each row produce one candidate:
- `"distro"` — when the Source column says **distro** (OpenStack ships in Ubuntu's
  main archive, no UCA needed).
- `"<uca-release>"` — the lowercase OpenStack release name shown in the Source column
  (e.g. `caracal`, `zed`, `wallaby`).

Print the list clearly, numbered. Example:

```
Available UCA / source options for Yoga on Focal:
  1. focal-yoga  → --release yoga  (UCA)
  2. distro      → (no --release needed, Ussuri ships in Focal main)
```

If only one option exists, confirm it with the user before proceeding.

---

## Step 4 — Collect any additional options

Ask if the user wants any extra `generate-bundle.sh` options. Common ones for
OpenStack/Neutron deployments:

- `--name <bundle-name>` — name for the bundle/model
- `--num-computes <n>` — number of nova-compute units
- `--ssl` — enable SSL/TLS
- `--dvr` — enable Distributed Virtual Routing
- `--ha` — deploy HA control plane
- `--octavia` — deploy Octavia load balancer
- `--designate` — deploy Designate DNS
- `--vault` — deploy Vault for secrets
- `--ceph` — integrate with Ceph storage
- `--ovn` / `--ovs` — choose OVN or OVS networking backend

The user may skip this step.

---

## Step 5 — Assemble and print the command

Compose the full command. The `--series` flag maps to the Ubuntu series name (e.g.
`focal`). The `--release` flag maps to the lowercase OpenStack release name (e.g.
`yoga`, `caracal`). If the source is `distro`, omit `--release`.

Template:
```
./generate-bundle.sh --series <series> [--release <openstack-release>] [<extra-opts>]
```

**Do NOT run the command.** Print it only, formatted in a code block.

Example final output:
```bash
./generate-bundle.sh --series focal --release yoga --num-computes 3 --ha
```

---

## Notes
- This skill targets `openstack/generate-bundle.sh` — run from the `openstack/` directory.
- The `--release` value is the lowercase OpenStack release name (e.g. `wallaby`,
  `yoga`, `caracal`), which matches the UCA pocket name.
- When OpenStack ships from the default archive (`distro`), omit `--release`.
- The `--pocket` flag (e.g. `--pocket proposed`) is for archive pockets and is
  separate from `--release`.
- Neutron is always bundled with the chosen OpenStack release — there is no separate
  Neutron-only `--release` option.
