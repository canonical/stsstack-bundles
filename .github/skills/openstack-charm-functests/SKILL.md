---
name: openstack-charm-functests
description: Run OpenStack charm functional tests locally using stsstack-bundles' `openstack/tools/charmed_openstack_functest_runner.sh`. Mirrors what OpenStack CI (OSCI) does — builds the charm, deploys the right test bundle, runs zaza/tempest, and reports per-target pass/fail. Use this whenever the user wants to run, re-run, or debug charm functional tests for a Charmed OpenStack charm (anything cloned from `opendev.org/openstack/charm-*`), validate a fix in a charm branch, reproduce an OSCI failure locally, pick the right `--func-test-target`, resume a failed test phase (`deploy`/`configure`/`test`), or wire in a `Func-Test-Pr` against zaza-openstack-tests. Trigger on phrases like "run functests", "run osci locally", "run zaza tests for charm X", "rerun the test phase", "validate this charm patch", or "what func-test-target should I use" — even when the user doesn't explicitly name the runner script. OpenStack reactive charms only (`charm-*` repos); not for ops-framework / `*-k8s` charms, and not for service-level OpenStack bugs (those go through `stsstack-bug-repro`).
---

# openstack-charm-functests

Run OpenStack charm functional tests the same way OSCI does, from a local charm clone, using
`openstack/tools/charmed_openstack_functest_runner.sh`.

## When to use

Trigger on any of these:

- "Run the functests for `charm-<name>`"
- "Reproduce the OSCI failure on this charm patch"
- "Validate this backport / cherry-pick on `stable/<release>`"
- "What `--func-test-target` should I pick for this bundle?"
- "Re-run just the `configure` (or `test`) phase — the deploy is fine"
- "Run charm X's tests with a pending zaza PR" → `--func-test-pr`

## When NOT to use

- **Service-level OpenStack bugs** (nova/neutron/cinder code) — use `stsstack-bug-repro` and the service path.
- **Ops-framework / `*-k8s` charms** — they use their own integration tests (`tox -e integration`, juju-based) and don't use `osci.yaml` / zaza in the same way.
- **Pure Ceph / standalone Ceph charms** (`charm-ceph-mon`, `charm-ceph-osd` without OpenStack) — the runner depends on an OpenStack tenant being present (it reads `~/novarc` and probes `subnet_${OS_USERNAME}-psd-extra`).
- **Deploying a regular cloud** — that's `openstack/generate-bundle.sh` (see `openstack-bundle-planner`).

## Prerequisites (verify before running anything)

The runner is **not** self-contained. It assumes a working serverstack / prodstack tenant. Confirm:

1. **A `~/novarc`** with project credentials. The runner does `source ~/novarc` then expects the env to include `OS_USERNAME`.
2. **The per-user "psd-extra" network and subnet** exist in that tenant:
   - `openstack network show net_${OS_USERNAME}-psd-extra`
   - `openstack subnet show subnet_${OS_USERNAME}-psd-extra`
   If these are missing, the runner will exit early during VIP/FIP setup. Tell the user to set up their tenant per the stsstack onboarding (or pick a different profile).
3. **A working Juju controller** the user can `juju switch` into. Juju 3.x is assumed; the runner exports `TEST_JUJU3=1` and a Juju-3.6 zaza constraints file unless Juju is 2.9.
4. **Tooling on PATH**: `tox`, `yq` (auto-installed via snap if missing), `lxd` initialised (the runner does `lxd init --auto`), `charmcraft` snap (the runner refreshes it to the channel pinned in `osci.yaml`).
5. **The user is inside a charm clone** — the runner reads `metadata.yaml` (`CHARM_NAME=$(awk '/^name: .+/{print $2}' metadata.yaml)`) and `osci.yaml` from `$PWD`. Don't run it from `stsstack-bundles/`.

If any prerequisite is missing, stop and report — don't paper over it with guesses.

## The canonical workflow

This is the happy path. Each step is a confirmation gate (see "Confirmation gates" below).

### 1. Get to the right charm and branch

```bash
# Full clone (NOT shallow) — shallow clones miss older fix commits and break
# git log --grep / git branch --contains workflows.
git clone https://opendev.org/openstack/charm-<name>.git
cd charm-<name>
git checkout <branch>   # master | stable/<codename> | stable/<yyyy.N> | stable/<ubuntu-series>
```

Branch picking rules (the three styles in the wild):

- `master` → current dev cycle
- `stable/<codename>` (e.g. `stable/yoga`) or `stable/<yyyy.N>` (e.g. `stable/2024.1`) → OpenStack-service charms. Newer charms moved to the `yyyy.N` form around Antelope/Bobcat — `git branch -r | grep stable` tells you which scheme this charm uses.
- `stable/<ubuntu-series>` (e.g. `stable/jammy`) → data / infra charms that don't track the OpenStack release cycle (`charm-mysql-innodb-cluster`, `charm-percona-cluster`, `charm-rabbitmq-server`, etc.). Map the target OpenStack release to its Ubuntu LTS via `common/openstack_release_info`.

If the user is validating a patch, also do `git log --oneline -1` and surface the commit — the runner prints `commit $COMMIT_ID` in its final report and you want that to match what the user is testing.

### 2. Pick a `--func-test-target`

Targets come from the charm's own CI definition, not from a global list. See
`references/discover-targets.md` for the full lookup procedure. The short version:

- Read `osci.yaml` at the charm root — the runner uses
  `python3 func_test_tools/identify_charm_func_test_jobs.py` against this file when no target is passed.
- Each target name in `osci.yaml` resolves (via `extract_job_target.py`) to a bundle name under
  `tests/bundles/` (or `src/tests/bundles/` for source-form charms).
- If the user doesn't specify a target, the runner runs **all** voting targets first, then non-voting ones.
  This is correct for "reproduce OSCI exactly" but expensive — for a specific bug you almost always want a single `--func-test-target`.

If the user gives a tempest test name or a zaza scenario, map it to a target by `grep`ing the bundle files under `tests/bundles/` for the test selector — the bundle's `tests.yaml` lists the zaza/tempest classes it runs.

### 3. Invoke the runner

From inside the charm clone (not from `stsstack-bundles/`):

```bash
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target> \
    [--func-test-pr <zaza-pr-id>] \
    [--manual-functests] \
    [--skip-build | --remote-build user@host,/path/to/charm] \
    [--rerun deploy|configure|test] \
    [--no-wait] \
    [--skip-modify-bundle-constraints] \
    [--sleep <seconds>]
```

What the runner does, in order (see source if unsure):

1. Reads `metadata.yaml`, gets `CHARM_NAME` and short commit.
2. Sources `~/novarc`, computes a per-user FIP range from `subnet_${OS_USERNAME}-psd-extra` (starts 64 IPs into the subnet), allocates two zaza VIPs, exports `TEST_*` env vars zaza expects.
3. Refreshes `charmcraft` to the channel in `osci.yaml` (or skips with a message if absent), `lxd init --auto`, then `tox -re build` — unless `--skip-build` (or `--remote-build`, which implies skip-build and rsyncs the `.charm` artefact back).
4. If `rename.sh` is missing post-build, renames `<charm>_*.charm` → `<charm>.charm`.
5. Optionally `apply_func_test_pr` for `--func-test-pr`.
6. Builds the target list (single `--func-test-target` or full OSCI default).
7. Optionally edits `tests/bundles/*.yaml` to set `nova-compute` constraints to `root-disk=80G mem=8G` so VMs fit (suppress with `--skip-modify-bundle-constraints` if your bundle is already correct).
8. For each target: destroy any pre-existing `zaza-*` model, run `tox -re func-target -- <target>` (or `manual_functests_runner.sh` if `--manual-functests`), capture pass/fail.
9. On failure → `retry_on_fail` interactive prompt: pick a phase (`deploy`/`configure`/`test`) to re-run, repeat until pass or exit.
10. Between targets: prompts `Destroy model and run next test? [ENTER]` unless `--no-wait`.
11. Final per-target pass/fail report; full log saved to a `mktemp` file (printed at the end).

Flag-by-flag details, including edge cases like `--rerun`'s requirement that exactly one `--func-test-target` is passed, are in `references/flags.md`.

### 4. Read the result

The runner prints, at the end:

```
Test results for charm <name> functional tests @ commit <sha>:
  * <target>: SUCCESS | FAILURE | SKIPPED [ (non-voting)]
...
Results also saved to /tmp/tmp.XXXXXXX-charm-func-test-results
```

- `SUCCESS` on the relevant target → the patch/branch behaves as expected.
- `FAILURE` → look at the captured logfile, then decide whether to `--rerun` a specific phase, switch to `--manual-functests` to control the loop yourself, or treat the bug as still reproducing.
- `SKIPPED` → target was queued but never executed (usually because the loop exited early after a prior failure).

For interpreting failures, see `references/troubleshooting.md`.

## Common workflows

### Validate a patch on a single target

```bash
cd charm-<name>
git fetch gerrit refs/changes/.../1 && git checkout FETCH_HEAD
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target>
```

### Iterate quickly after a build is already good

```bash
# After the first run built the charm successfully:
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target> --skip-build
```

### Test against an in-flight zaza-openstack-tests PR

```bash
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target> --func-test-pr <pr-id>
```

This mirrors the `Func-Test-Pr:` footer used in charm commit messages.

### Re-run only the test phase against an already-deployed model

```bash
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target> --rerun test
```

Rules:

- `--rerun` **requires** exactly one `--func-test-target` (the runner errors out otherwise and prints the available targets).
- The runner finds the live `zaza-*` model via `juju list-models` and `juju switch`es to it.
- Use `--rerun deploy` only if the previous deploy was destroyed — it will re-run `functest-deploy` on a fresh model.

### Build remotely, test locally

```bash
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target> \
    --remote-build ubuntu@build-host,~/git/charm-<name>
```

Useful when the local machine is small or LXD-constrained. Implies `--skip-build`; the `.charm` is rsynced back.

### "Run everything OSCI would run"

```bash
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh
```

No target → all voting targets first, then non-voting. Expensive (hours). Only suggest this if the user explicitly asks for full OSCI equivalence.

## Confirmation gates for mutating commands

Read-only operations run without asking: file reads, `--help`, `git clone` / `git checkout` / `git log`,
`juju status`, `openstack ... show`, `cat osci.yaml`.

These each prompt for confirmation **once per invocation**. Approval for one does NOT carry to the next:

- `charmed_openstack_functest_runner.sh` (always — it builds, deploys, runs tests, destroys models).
- `tox -re build` if invoked outside the runner.
- Any `juju destroy-model` you suggest manually.

If the user declines, output the exact command for them to run by hand and stop.

## Hard rules

- **Run from the charm root**, not from `stsstack-bundles/`. The runner uses `$PWD` to find `metadata.yaml` and `osci.yaml`.
- **Full clone, not shallow.** Shallow clones break the target-discovery scripts (they walk history) and break the bug-fix-locating workflow you'll often pair with this skill.
- **Don't invent target names.** Only use targets that appear in the charm's `osci.yaml`. If `identify_charm_func_test_jobs.py` lists nothing, stop and report — the charm is probably misconfigured or this is the wrong charm type.
- **Don't bypass prerequisite checks.** If `~/novarc` or `*-psd-extra` resources are missing, fix that first; the runner can't proceed without them.
- **One `--func-test-target` with `--rerun`.** The runner enforces this; replicate the same check before suggesting a command.
- **No secrets in output.** `novarc` is sourced into the runner's env; don't echo `OS_PASSWORD` / `OS_AUTH_TOKEN` back to the user.

## Examples

**Validate a backport on `stable/2024.1`**
User: "Can you run the functests for my keystone-saml-mellon backport on caracal?"
→ Confirm prerequisites (novarc, psd-extra net/subnet, Juju controller). → `cd charm-keystone-saml-mellon && git checkout stable/2024.1` → grep `osci.yaml` for the SAML target → propose `charmed_openstack_functest_runner.sh --func-test-target <target>` → confirm with user → run → report SUCCESS/FAILURE with the logfile path.

**"Which target should I run for the OVN HA bug?"**
User: "I want to reproduce the OVN chassis-cleanup bug in charm-neutron-api"
→ `cd charm-neutron-api && cat osci.yaml` → list candidate targets → cross-reference `tests/bundles/*ovn*ha*.yaml` → recommend the matching `--func-test-target` and explain why (bundle wires OVN + N hacluster units). Don't run anything yet; wait for the user to pick.

**Iterating after a failure**
User: "It failed in the configure phase, I tweaked the charm code"
→ If they rebuilt: `--rerun configure`. → If they didn't change charm code, just zaza config: `--rerun configure` on the existing model without rebuilding. → If the deploy itself was broken and they destroyed the model: full re-run with `--skip-build` (the previous `.charm` is reused).

**Rejection**
User: "Run the functests for charm-microk8s"
→ Reject: "This skill is for reactive OpenStack charms (`opendev.org/openstack/charm-*`). `charm-microk8s` is an ops-framework / k8s charm — use its own `tox -e integration` test harness instead."

## Reference files

- `references/discover-targets.md` — how to extract valid `--func-test-target` values from `osci.yaml` and the helper scripts in `func_test_tools/`.
- `references/flags.md` — complete flag reference with edge cases and interactions.
- `references/troubleshooting.md` — common failure modes (build errors, missing psd-extra, zaza model leftovers, voting vs non-voting, model name lookup) and how to recover.
