# Cross-branch fix status (step 6)

After repro (success or failure), produce a branch-by-branch fix-status report and a recommended next action. Applies to both paths.

## 8.1 Locate the fix commits

```
cd <charm-or-service-clone>
git fetch --all
git log --all --oneline \
        --grep "Closes-Bug: #<num>" \
        --grep "Related-Bug: #<num>" \
        --grep "Partial-Bug: #<num>" \
        --grep "LP#<num>" -i
```

If `git log --grep` returns nothing, **Gerrit fallback**:

1. On the LP bug page, each `Fix proposed` / `Fix committed` / `Fix released` row links to a Gerrit review (`https://review.opendev.org/c/<project>/+/<n>`).
2. WebFetch the Gerrit review and read the `Change-Id: I<hex>` from the commit message.
3. Search the local repo by Change-Id:
   ```
   git log --all --oneline --grep "Change-Id: I<hex>"
   ```
4. Still nothing → the patch hasn't landed in this project's git tree yet (under review, abandoned, or in a different repo). Note this in the report.

## 8.2 Enumerate target branches

```
git branch -r | grep -E '^  origin/(master|main|stable/.+)$'
```

## 8.3 Build the status table

For each target branch:

```
git log <branch> --oneline --grep "Closes-Bug: #<num>" -i
# or, with the fix SHA:
git branch -r --contains <fix-sha>
```

Output:

| Branch | Fix present | Commit |
|---|---|---|
| master | ✅ | abc1234 "Fix LP#<num> ..." |
| stable/2025.1 | ✅ | def5678 (cherry-pick of abc1234) |
| stable/2024.2 | ❌ | — |
| stable/2024.1 | ❌ | — |

## 8.4 Classify branch support — service vs charm rules differ

**Service-level (upstream OpenStack) projects** follow the releases.openstack.org labels captured in SKILL.md step 3:

- **Maintained** — receives bugfix backports.
- **Extended Maintenance (EM)** — security/critical backports only, at community discretion.
- **Unmaintained / EOL** — no backports.

**Charm projects** (opendev `openstack/charm-*`) do NOT follow the upstream EOL clock 1:1. Canonical keeps older charm branches alive longer to track Ubuntu LTS support windows — `stable/yoga` may still receive patches long after upstream Yoga is EOL. Determine charm-branch support empirically:

```
git log <branch> --since "6 months ago" --oneline | head
```

If a branch has commits in the last ~6 months, treat it as **supported** (backport candidate) regardless of upstream OpenStack label. If silent for longer, treat it as **inactive** (no backport obligation). Record the rule and the most-recent commit date for each branch in your report.

## 8.5 Recommend next action

- **Fix absent everywhere (including master)** — guide patch progression. Order: master first, then active branches newest → oldest (service: Maintained; charm: empirically-supported). Per OpenStack stable policy, backports require the master merge first, then cherry-pick to each stable in sequence. State the order; don't skip branches. Also produce the patch proposal in 8.6.
- **Fix on master only** — list backport candidates = every active stable. Call out EM/inactive stables separately as "optional, only if security-class". Exclude EOL.
- **Fix on master + some stables** — list the remaining active stables that still need backports. Note inactive/EM stables that still lack the patch as optional.
- **Fix on all active branches** — bug is fully fixed. Recommend closing the LP if still open. Optionally, keep a regression test exercising the trigger.

Don't actually create patches, push to Gerrit, or modify branches. Output the plan; let the user act.

## 8.6 Propose a patch when none exists

If 8.1 found no fix on any branch and the repro succeeded, propose a concrete patch direction based on the reproduction evidence:

1. **Symptom → suspected component** — from the failing command output, log line, or stack trace, identify the file:function most likely responsible (e.g., `nova/conductor/tasks/live_migrate.py::bind_ports_to_host`).
2. **Inspect the code** — read that function on the reproduction branch. Match what the trace says against what the code does. Identify the exact condition, missing check, or wrong default.
3. **Sketch the fix** — write the smallest change that addresses the root cause (not the symptom). Show it as a diff or function-level edit. Cite the file:line and the line of evidence from repro that maps to that line of code.
4. **Suggest a test** — name the existing test that should have caught this (and didn't), or describe a new case. For charms, this usually maps to a `--func-test-target` or a new zaza test; for services, a unit/integration test in `<project>/tests/`.
5. **Mark uncertainties** — flag what you couldn't verify from the repro alone (other code paths, race conditions, side effects on other releases).

This is a proposal, not a merge — output the diff/sketch for the user to validate. Don't push, commit, or open a review.
