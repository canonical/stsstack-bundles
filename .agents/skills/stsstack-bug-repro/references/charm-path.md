# Charm path (step 4A)

Each charm has its own test definitions (bundles, zaza configs, tempest selectors) under `tests/` in its repo. The OpenStack CI (OSCI) entry point lives at `osci.yaml`. stsstack-bundles ships `openstack/tools/charmed_openstack_functest_runner.sh`, which mimics OSCI from inside the charm checkout.

## 4A.0 — Locate the fix (if any) across branches first

Before deciding which branch to reproduce on, find out where the fix lives. This drives: (a) which branches still exhibit the bug, (b) which branches need a backport.

```
# Clone *full*, not shallow — shallow clones miss older fix commits.
git clone https://opendev.org/openstack/charm-<name>.git
cd charm-<name>
git log --all --oneline \
        --grep "Closes-Bug: #<num>" \
        --grep "LP#<num>" \
        --grep "lp:#<num>" -i
# List branches containing the fix:
git branch -r --contains <fix-sha>
```

If you cloned shallowly (`--depth N`) and the search returned nothing, run `git fetch --unshallow` and retry before declaring "no fix" — the fix may simply be deeper than your fetch window.

If `git log --grep` finds nothing even after unshallow, fall back to Gerrit (see `cross-branch.md` 8.1).

**Pick the reproduction branch** as the one matching the bug's release that does NOT contain the fix. If every branch already contains the fix, the bug should be closed/verified — confirm with the user before continuing. They may want pre-fix repro for regression-test validation: checkout the parent of the fix commit (`git checkout <fix-sha>^`).

## 4A.1 — Checkout the matching branch

Reuse the clone from 4A.0. Branch ↔ release map varies per charm — three styles in the wild:

- `master` → current dev
- `stable/<codename>` (e.g., `stable/caracal`, `stable/yoga`) — older OpenStack-service charms
- `stable/<yyyy.N>` (e.g., `stable/2024.1`) — newer OpenStack-service charms
- `stable/<ubuntu-series>` (e.g., `stable/jammy`, `stable/focal`) — **data/infra charms** that don't track OpenStack release cycles directly: `charm-mysql-innodb-cluster`, `charm-percona-cluster`, `charm-rabbitmq-server`, and similar. Map the bug's release to its contemporaneous Ubuntu LTS via `common/openstack_release_info` (`lts[]`) to pick the right branch.

Pick the branch matching the bug's release. `git branch -r | grep stable` shows what's actually there for this charm. If the bug's exact release has no branch, see `charm-types.md` for activity-based fallback rules.

```
git checkout stable/<release-or-yyyy.N>
```

If the bug pre-dates a fix that's already on this branch, checkout the parent of the fix commit (`<sha>^`) rather than reverting — don't silently rewrite history.

## 4A.2 — Run the functest runner

From inside the charm clone, invoke the runner that lives in stsstack-bundles:

```
<stsstack-bundles>/openstack/tools/charmed_openstack_functest_runner.sh \
    --func-test-target <target-from-osci.yaml> \
    [--manual-functests]              # split deploy/configure/test phases
    [--skip-build]                    # if you already built the charm
    [--rerun deploy|configure|test]   # resume after a phase
```

Read the charm's `osci.yaml` (or `src/tests/tests.yaml`) to find the right `--func-test-target`. The bug's trigger should map to one of those targets. If the bug refers to a specific tempest test, it usually corresponds to a charm test target whose bundle wires up tempest with the right selectors.

The runner handles the full cycle (build → deploy → configure → run tests). Don't separately invoke `generate-bundle.sh` for the charm path — the runner uses bundles from the charm's `tests/` dir.

`--manual-functests` is useful for intermittent bugs: deploy once, then re-run only the test phase under different conditions.

## 4A.3 — Verify

See `SKILL.md` step 5.
