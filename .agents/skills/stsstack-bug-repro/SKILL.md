---
name: stsstack-bug-repro
description: Reproduce a Charmed OpenStack bug locally from a public Launchpad bug. Classifies as a charm bug (clone the charm from opendev, run `charmed_openstack_functest_runner.sh`) or a service-level bug (deploy via stsstack-bundles, trigger manually), executes mutating steps only with explicit per-step confirmation, then verifies and reports cross-branch fix status with backport guidance. Use whenever the user mentions an LP bug number/URL, asks to reproduce an OpenStack symptom locally, or wants a stsstack-bundles setup for a specific bug — even if they don't say "reproduce". OpenStack only; rejects non-OpenStack components and private LP bugs.
---

# stsstack-bug-repro

Translate a Charmed OpenStack bug into a runnable reproduction, then — with confirmation — execute and verify it.

## When to use

The user gives you a Charmed OpenStack bug to reproduce. Typical inputs:

- Public Launchpad bug number/URL (e.g., `LP#2089616`, `https://bugs.launchpad.net/...`)
- Symptom description in an OpenStack component ("HA Keystone fails on Caracal", "Octavia LB stuck in PENDING_CREATE on OVN", ...)
- "Set up an env where I can hit X" for an OpenStack scenario

## When NOT to use — reject upfront

Stop and tell the user the skill cannot proceed:

- **Private LP bug** — JSON has `"private": true`, page says "This bug is private", or WebFetch returns 401/404. Ask the user to make it public or paste the relevant text. Don't try to bypass.
- **Not an OpenStack component** — pure Ceph (`ceph-mon`, `ceph-osd`, `rbd`, `cephfs` standalone), pure Kubernetes / Charmed K8s, ops-framework charms (COS, MicroK8s, identity-platform, `*-k8s`), Kafka, JAAS, Landscape, OSM, Swift-standalone. See `references/charm-types.md` for why ops charms are out of scope.
- **Bug in stsstack-bundles itself** (template/script) — treat as a normal code task.
- **Normal deployment request** — point at `openstack/generate-bundle.sh --help` and `openstack/AGENTS.md`.
- **RFE / blueprint / architectural change** — title starts with `[RFE]`, `[Spec]`, `[Feature]`, body uses "request"/"support"/"deprecate", or Launchpad importance is `Wishlist`. This skill reproduces existing defects; RFEs have no trigger to reproduce ("missing feature" is the symptom). Tell the user to use a feature-design workflow instead.

OpenStack bugs that *involve* Ceph or K8s as a backend (Cinder-Ceph, Manila-CephFS, Magnum-K8s) are in scope — they go in via overlays, not a separate stack.

## Read first

- `AGENTS.md` (repo root) and `openstack/AGENTS.md` — source of truth for stack layout, options, overlays, conventions.
- `common/openstack_release_info` — release/series mapping. Details in `references/release-mapping.md`.
- `https://releases.openstack.org/` — WebFetch every time to know the current dev cycle and per-series support status (Maintained/EM/EOL). Training data goes stale within a 6-month cycle.

## Procedure

### 1. Fetch the Launchpad bug

WebFetch both:
- Human page: `https://bugs.launchpad.net/+bug/<num>`
- JSON: `https://api.launchpad.net/devel/bugs/<num>`

If the response indicates private/inaccessible → reject (see above). If the user pasted the bug text directly, skip the fetch and extract from that text.

Extract: affected project / source package, OpenStack release / charm channel, Ubuntu series, symptom and trigger. Don't echo private comments or credentials — reference them as "LP comment #N" without quoting.

### 2. Classify

Choose the **charm path** when any holds:

- LP project is `charm-<name>` (opendev `openstack/charm-*`, reactive framework).
- Bug references charm config, charm channels/tracks, or a failing CI test target (osci.yaml, zaza, charm-CI tempest selector).
- Reporter pasted `juju config` / `juju status` as the trigger artefact.

Otherwise use the **service-level path** — the bug is in the OpenStack service code itself; deployment is incidental.

If unclear, ask once: "Is this a charm bug (CI-equivalent repro via the charm repo) or a service-level bug (manual repro on a stsstack-bundles cloud)?"

### 3. Extract dimensions

Identify and mark unknowns explicitly (don't invent):

- OpenStack release + Ubuntu series
- Charm channel/track (also drives charm branch)
- HA topology (single vs N units + hacluster)
- Optional components (Vault, LDAP, Octavia, Heat, Designate, Manila, Magnum, Barbican, Ceph, K8s integration)
- Network plugin (ML2-OVS vs ML2-OVN)
- Provider/substrate (MAAS, LXD, OS-on-OS, public cloud)
- Profile (`default` / `stsstack` / `serverstack` / `prodstack5|6|7` / `metal`)
- Trigger action — for charm path usually a `--func-test-target`; for service path a CLI/API call or test

**If release/series is not specified**, choose the default based on bug age:

- **Recent bug** (created in the last ~2 years) → current dev release (codename from `https://releases.openstack.org/`).
- **Old bug** (>2 years old, no release stated) → a release **contemporary with the bug's creation date**, not current dev. A 2019 bug almost certainly targeted Rocky/Stein/Train, and reproducing it on Hibiscus is misleading (the code path may not exist anymore). Cross-check with `git log <suspected-area> --before <bug-creation-date>`.

If the chosen codename isn't in `common/openstack_release_info`, see `references/release-mapping.md` for the fallback rule.

**If the bug lists a release range** (e.g., "ussuri through xena", "yoga / 2023.1 / 2023.2", "rocky and later"), ask the user which to reproduce on, or default to the **most recent affected release that is still active** (per releases.openstack.org Maintained status + charm activity heuristic). State the choice in the recipe so the user can override.

Also from releases.openstack.org, capture each series' support status (Maintained / EM / Unmaintained / EOL) — step 6 needs it.

### 4. Execute the path

- **Charm path** → follow `references/charm-path.md` (locate the fix across branches, checkout, run the functest runner).
- **Service path** → follow `references/service-path.md` (map dimensions to flags/overlays, produce a recipe, generate/deploy/configure/trigger).

### 5. Verify reproduction

- Charm path: read the runner's exit status and the zaza/tempest output.
- Service path: run the observation commands from the recipe.

Call out **reproduced**, **did not reproduce**, or **inconclusive**. On reproduction, report the matching evidence (command output, log line, status field) — don't paste secrets. On failure-to-reproduce, collect the logs listed in the recipe and suggest the next dimension to vary (flip OVS↔OVN, switch profile, try a different channel).

### 6. Cross-branch fix status and backport guidance

After step 5, produce a branch-by-branch fix-status report. Service-level uses the upstream OpenStack Maintained/EM/EOL labels; charms use an activity heuristic instead (Canonical keeps older charm branches alive past upstream EOL). Details in `references/cross-branch.md`, including:

- locating fix commits (and the Gerrit Change-Id fallback when `git log --grep` is empty),
- the status table format,
- service-vs-charm classification rules,
- recommended next action per fix-presence pattern,
- a patch proposal sketch when no fix exists anywhere (step 5 evidence → file:function → smallest diff → test).

### 7. Confirmation gates for mutating commands

Read-only inspection runs without asking: file reads, `./generate-bundle.sh --help` / `--list-overlays`, `git clone` / `git checkout` / `git log`, `juju status`, log fetches, WebFetch.

Each of these prompts for confirmation, one at a time. Approval for one step does NOT carry to the next. If the user declines, output the command for manual execution.

- **Charm path**: `charmed_openstack_functest_runner.sh` (deploys a model).
- **Service path**: `generate-bundle.sh`, deploy, `configure`, trigger.

## Hard rules

- **OpenStack only.** Non-OpenStack or private LP bug → reject and stop. (Why: scope; private bugs may contain customer data.)
- **Confirm before each mutating step.** Each consumes real resources (Juju model, VMs/units, time). Re-confirm per step.
- **Don't invent flag or overlay names.** Use only what `--help` / `--list-overlays` show. If missing, stop and say so.
- **Cite evidence** for non-obvious mappings (file:line).
- **No secrets** echoed from LP. Reference as "found in LP comment #N" without quoting.

## Examples

**Charm bug, fix already on all branches**
User: "Reproduce LP#1877168"
→ Fetch → charm-nova-compute, OpenStack Train → clone charm-nova-compute → `git log --grep "1877168"` finds `d6a1c4f` "Fix cpu_dedicated_set generation in nova.conf" → `git branch -r --contains d6a1c4f` shows all stable branches → report "already fixed everywhere; reproduce only if user wants pre-fix validation" → wait for user.

**Service bug, release not specified**
User: "Set up an env for LP#2051907"
→ Fetch → upstream nova, live-migrate policy issue, no release stated → WebFetch releases.openstack.org → current dev = Hibiscus (2026.2) → grep `common/openstack_release_info` → Hibiscus absent → fall back to Flamingo (2025.2, latest supported), note the deviation → produce recipe with `--release flamingo --series questing --num-compute 2`, trigger via `openstack server live-migrate ...` → ask per-step confirmation.

**Rejection**
User: "Reproduce LP#1979330"
→ Fetch → charm-ceph-mon, no OpenStack involvement → reject: "This skill is OpenStack-only. For pure Ceph charm bugs, use the stsstack-bundles `ceph/` stack directly — see `ceph/AGENTS.md` if present."
