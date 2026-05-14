---
name: ceph-bundle-gen
description: 'Generate a Ceph bundle generate-bundle.sh command interactively. Use when generating ceph bundles, choosing Ceph version, Ubuntu series, UCA release, or building the generate-bundle.sh command for ceph deployment. Guides user through: Ubuntu version → Ceph version → UCA release selection → final command assembly.'
argument-hint: 'Optional initial parameters, e.g. ubuntu=jammy ceph=19'
---

# Ceph Bundle Generation Workflow

## Purpose
Interactively guide the user to assemble a `./generate-bundle.sh` command for Ceph
deployments by selecting compatible Ubuntu series, Ceph version, and UCA release,
referencing the official [Ceph and the UCA](https://wiki.ubuntu.com/OpenStack/CloudArchive#Ceph_and_the_UCA) table.

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

## Step 2 — Derive valid Ceph versions for that Ubuntu release

Using the [Ceph and the UCA table](https://wiki.ubuntu.com/OpenStack/CloudArchive#Ceph_and_the_UCA) embedded below, look up which Ceph releases are available (both from the default archive and via UCA) for the chosen Ubuntu series.

### Ceph and the UCA reference table

| Ceph release | Default archive | UCA release        | Ubuntu LTS |
|--------------|-----------------|--------------------|------------|
| Squid        | yes             | -                  | Noble      |
| Squid        | -               | jammy-caracal      | Jammy      |
| Reef         | -               | jammy-bobcat       | Jammy      |
| Quincy       | yes             | -                  | Jammy      |
| Quincy       | -               | focal-yoga         | Focal      |
| Pacific      | -               | focal-xena         | Focal      |
| Pacific      | -               | focal-wallaby      | Focal      |
| Octopus      | yes             | -                  | Focal      |
| Octopus      | -               | bionic-ussuri      | Bionic     |
| Nautilus     | -               | bionic-train       | Bionic     |
| Mimic        | -               | bionic-stein       | Bionic     |
| Mimic        | -               | bionic-rocky       | Bionic     |
| Luminous     | yes             | -                  | Bionic     |
| Luminous     | -               | xenial-queens      | Xenial     |
| Jewel        | yes             | -                  | Xenial     |
| Jewel        | -               | trusty-mitaka      | Trusty     |
| Firefly      | yes             | -                  | Trusty     |

### Ceph version number → code name mapping

Reference: [docs.ceph.com/en/latest/releases/](https://docs.ceph.com/en/latest/releases/)

| Major version | Code name |
|---------------|-----------|
| 20            | Tentacle  |
| 19            | Squid     |
| 18            | Reef      |
| 17            | Quincy    |
| 16            | Pacific   |
| 15            | Octopus   |
| 14            | Nautilus  |
| 13            | Mimic     |
| 12            | Luminous  |
| 10            | Jewel     |
| 0.80          | Firefly   |

Ask the user for the Ceph version they want. Accept a **major version number** (e.g. `17`, `18`, `19`) **or** a code name (e.g. `Quincy`). Resolve the number to a code name using the table above. Then confirm the resolved code name to the user.

---

## Step 3 — List all valid UCA releases for the chosen combination

Cross-reference the Ubuntu series and the resolved Ceph code name in the table above. Collect **all** matching rows.

For each row produce one candidate. The candidate is either:
- `"distro"` — when the "Default archive" column is **yes** (Ceph ships in Ubuntu's main archive, no UCA needed).
- `"<uca-release>"` — the value from the "UCA release" column (e.g. `focal-wallaby`).

Print the list clearly, numbered, so the user can choose. Example output:

```
Available UCA / source options for Quincy on Focal:
  1. focal-yoga   (UCA)
  2. distro       (default archive – Jammy ships Quincy in main)
```

If only one option exists, confirm it with the user before proceeding.

---

## Step 4 — Collect any additional options

Ask if the user wants to provide any extra `generate-bundle.sh` options such as:
- `--name <bundle-name>` — name for the bundle/model
- `--num-mons <n>` — number of ceph-mon units
- `--num-osds-per-host <n>` — OSDs per host
- `--no-openstack` — skip OpenStack charms
- `--ssl` — enable SSL
- `--rgw` / `--ceph-rgw` — add RADOS Gateway
- `--ceph-fs` — add CephFS
- `--vault` — add Vault

The user may skip this step.

---

## Step 5 — Assemble and print the command

Compose the full command. The `--series` flag maps to the Ubuntu series name (e.g. `focal`). The `--release` flag maps to the OpenStack release name that corresponds to the chosen UCA pocket (look up the UCA release name in the table; strip the `<series>-` prefix to get the release name, e.g. `focal-wallaby` → `wallaby`). If the source is `distro`, omit `--release`.

Template:
```
./generate-bundle.sh --series <series> [--release <uca-openstack-release>] [<extra-opts>]
```

**Do NOT run the command.** Print it only, formatted in a code block.

Example final output:
```bash
./generate-bundle.sh --series focal --release wallaby --num-mons 3
```

---

## Notes
- This skill is located at `ceph/generate-bundle.sh` — always run from the `ceph/` directory.
- The `--release` value is the OpenStack release name (e.g. `wallaby`, `yoga`), NOT the UCA pocket name (`focal-wallaby`). Strip the `<series>-` prefix.
- When Ceph ships from the default archive (`distro`), no `--release` flag is needed for the Ceph source; omit it unless the user also wants an OpenStack UCA release.
- The `--pocket` flag (e.g. `--pocket proposed`) is for archive pockets and is separate from `--release`.
