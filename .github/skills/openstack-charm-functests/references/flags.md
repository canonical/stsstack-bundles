# charmed_openstack_functest_runner.sh — Flag Reference

All flags for `openstack/tools/charmed_openstack_functest_runner.sh`. Run from the charm root.

## `--func-test-target TARGET_NAME`

Specific OSCI target to run. Repeatable — can be specified multiple times for a subset of targets.
If omitted, the runner discovers and runs **all** targets from `osci.yaml` (voting first, then non-voting).

**Interaction with `--rerun`**: When using `--rerun`, exactly one `--func-test-target` is required. The runner exits with an error and prints the available targets if this rule is violated.

## `--func-test-pr PR_ID`

Apply a pending Pull Request from `zaza-openstack-tests` before running tests. Mirrors the `Func-Test-Pr:` commit-message footer used in charm CI. The PR is applied inside the `func-target` tox environment after it's created.

## `--manual-functests`

Run functest phases (`deploy`, `configure`, `test`) one at a time with interactive prompts between them, instead of running the full suite end-to-end. Uses `manual_functests_runner.sh` internally. The model name pattern changes from `zaza-*` to `test-<target>`.

Useful for:
- Intermittent bugs — deploy once, rerun only the test phase.
- Debugging bundle/config issues — stop after deploy and inspect with `juju status`.

## `--rerun deploy|configure|test`

Re-run a single phase against an already-deployed model. Requires exactly one `--func-test-target`.

The runner finds the live `zaza-*` model via `juju list-models`, `juju switch`es to it, and runs only the specified phase. If the phase fails, the interactive `retry_on_fail` loop offers to retry or pick a different phase.

**Typical patterns:**
- `--rerun test` — re-run tests after editing test code / zaza config (no re-deploy).
- `--rerun configure` — re-configure after adjusting charm config.
- `--rerun deploy` — re-deploy to a fresh model (previous model must be destroyed first).

## `--skip-build`

Skip the `tox -re build` step. Reuses a previously built `.charm` artefact in `$PWD`. Saves significant time on iterative runs. Implied by `--remote-build`.

## `--remote-build USER@HOST,GIT_PATH`

Build the charm on a remote machine and rsync the `.charm` file back. Format: `user@host,/path/to/charm-clone`. The remote must have build tools pre-installed (tox, charmcraft, lxd). Implies `--skip-build` for the local side.

## `--no-wait`

Don't pause between targets. By default the runner prompts `Destroy model and run next test? [ENTER]` after each target completes. This flag skips that prompt and immediately destroys the model and moves on.

## `--skip-modify-bundle-constraints`

Don't patch `tests/bundles/*.yaml` to add `nova-compute` constraints. By default the runner sets `nova-compute` constraints to `root-disk=80G mem=8G` so test VMs have enough space. Use this flag if the bundle already has correct constraints or the tests don't deploy `nova-compute`.

## `--sleep TIME_SECS`

Sleep between functest phases. Only meaningful with `--manual-functests` (passed to `manual_functests_runner.sh`). Useful when phases need settling time (e.g. waiting for pacemaker to stabilise).

## `--debug`

Enables `set -x` for the entire runner. Very verbose; use for troubleshooting the runner itself, not the charm tests.

## `--help` / `-h`

Print usage and exit.
