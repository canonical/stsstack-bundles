---
name: nova-bundle-gen
description: 'Generate a Nova/OpenStack bundle generate-bundle.sh command interactively. Use when generating nova bundles, choosing nova version, Ubuntu series, UCA release, or building the generate-bundle.sh command for OpenStack/Nova deployment. Guides user through: Ubuntu version → Nova version → UCA release selection → final command assembly.'
argument-hint: 'Optional initial parameters, e.g. ubuntu=jammy nova=29'
---

# Nova Bundle Generation Workflow

## Purpose
Interactively guide the user to assemble a `./generate-bundle.sh` command for
OpenStack/Nova deployments by selecting compatible Ubuntu series, Nova version,
and UCA release, referencing the official [Ubuntu Cloud Archive](https://wiki.ubuntu.com/OpenStack/CloudArchive)
and [Nova releases](https://releases.openstack.org/teams/nova.html) pages.

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

## Step 2 — Derive valid Nova/OpenStack versions for that Ubuntu release

Using the reference table below, look up which OpenStack releases (and thus Nova
versions) are available for the chosen Ubuntu series, both from the default archive
and via UCA.

### Ubuntu → OpenStack / Nova availability table

Reference: [wiki.ubuntu.com/OpenStack/CloudArchive](https://wiki.ubuntu.com/OpenStack/CloudArchive) and [releases.openstack.org/teams/nova.html](https://releases.openstack.org/teams/nova.html)

| Ubuntu series | OpenStack release  | Nova major | Source          |
|---------------|--------------------|------------|-----------------|
| Noble (24.04) | Epoxy (2025.1)     | 31         | UCA `epoxy`     |
| Noble (24.04) | Dalmatian (2024.2) | 30         | UCA `dalmatian` |
| Noble (24.04) | Caracal (2024.1)   | 29         | distro          |
| Jammy (22.04) | Caracal (2024.1)   | 29         | UCA `caracal`   |
| Jammy (22.04) | Bobcat (2023.2)    | 28         | UCA `bobcat`    |
| Jammy (22.04) | Antelope (2023.1)  | 27         | UCA `antelope`  |
| Jammy (22.04) | Zed                | 26         | UCA `zed`       |
| Jammy (22.04) | Yoga               | 25         | distro          |
| Focal (20.04) | Yoga               | 25         | UCA `yoga`      |
| Focal (20.04) | Xena               | 24         | UCA `xena`      |
| Focal (20.04) | Wallaby            | 23         | UCA `wallaby`   |
| Focal (20.04) | Ussuri             | 21         | distro          |
| Bionic (18.04)| Ussuri             | 21         | UCA `ussuri`    |
| Bionic (18.04)| Train              | 20         | UCA `train`     |
| Bionic (18.04)| Stein              | 19         | UCA `stein`     |
| Bionic (18.04)| Rocky              | 18         | UCA `rocky`     |
| Bionic (18.04)| Queens             | 17         | distro          |
| Xenial (16.04)| Queens             | 17         | UCA `queens`    |
| Xenial (16.04)| Mitaka             | 13         | distro          |
| Trusty (14.04)| Mitaka             | 13         | UCA `mitaka`    |
| Trusty (14.04)| Icehouse           | (2014.1.x) | distro          |

### Full Nova version number → OpenStack release mapping

Reference: [releases.openstack.org/teams/nova.html](https://releases.openstack.org/teams/nova.html)

| Nova major | OpenStack release  |
|------------|--------------------|
| 33         | Gazpacho (2026.1)  |
| 32         | Flamingo (2025.2)  |
| 31         | Epoxy (2025.1)     |
| 30         | Dalmatian (2024.2) |
| 29         | Caracal (2024.1)   |
| 28         | Bobcat (2023.2)    |
| 27         | Antelope (2023.1)  |
| 26         | Zed                |
| 25         | Yoga               |
| 24         | Xena               |
| 23         | Wallaby            |
| 22         | Victoria           |
| 21         | Ussuri             |
| 20         | Train              |
| 19         | Stein              |
| 18         | Rocky              |
| 17         | Queens             |
| 16         | Pike               |
| 15         | Ocata              |
| 14         | Newton             |
| 13         | Mitaka             |
| 12         | Liberty            |

Present to the user the available Nova versions (with their OpenStack names and major
version numbers) for the chosen Ubuntu series. Accept either a **major version number**
(e.g. `29`) **or** an **OpenStack release name** (e.g. `Caracal`). Resolve to a
release name and confirm with the user.

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
Available UCA / source options for Wallaby on Focal:
  1. wallaby  → --release wallaby  (UCA)
```

If only one option exists, confirm it with the user before proceeding.

---

## Step 4 — Collect any additional options

Ask if the user wants any extra `generate-bundle.sh` options. Common ones for
OpenStack/Nova deployments:

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
./generate-bundle.sh --series focal --release wallaby --num-computes 3 --ha
```

---

## Notes
- This skill targets `openstack/generate-bundle.sh` — run from the `openstack/` directory.
- The `--release` value is the lowercase OpenStack release name (e.g. `wallaby`,
  `yoga`, `caracal`), which matches the UCA pocket name.
- When OpenStack ships from the default archive (`distro`), omit `--release`.
- The `--pocket` flag (e.g. `--pocket proposed`) is for archive pockets and is
  separate from `--release`.
- Nova is always bundled with the chosen OpenStack release — there is no separate
  Nova-only `--release` option.
