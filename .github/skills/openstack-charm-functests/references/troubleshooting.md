# Troubleshooting charm functional tests

Common failure modes when running `charmed_openstack_functest_runner.sh` and how to recover.

## Build failures

### `charmcraft` snap channel mismatch
**Symptom:** `charmcraft` errors about unsupported config keys or schema validation.
**Cause:** The runner refreshes `charmcraft` to the channel in `osci.yaml` (`charmcraft_channel`). If `osci.yaml` doesn't have that key, it skips the refresh — you may be on the wrong channel.
**Fix:** Check `snap info charmcraft` and compare with what OSCI uses for this charm branch. Manually `sudo snap refresh charmcraft --channel <correct-channel>`.

### LXD not initialised
**Symptom:** `lxd init --auto` fails, or charmcraft-build fails trying to talk to LXD.
**Cause:** Fresh machine without LXD setup.
**Fix:** `sudo lxd init --auto` manually. Ensure the user is in the `lxd` group (`newgrp lxd` or re-login).

### `tox -re build` fails with missing dependencies
**Symptom:** tox environment creation errors (missing `charmcraft`, `pip`, Python version mismatch).
**Fix:** Some charms need specific Python versions (3.8, 3.10, 3.12). Check `tox.ini` `basepython` and ensure it's installed. `deadsnakes` PPA if needed.

## Deployment failures

### Missing `~/novarc` or `*-psd-extra` network
**Symptom:** Runner errors immediately after sourcing `~/novarc` — `openstack subnet show` returns "No resource found" or auth errors.
**Cause:** Either `novarc` points to the wrong project, or the per-user `psd-extra` network was never created.
**Fix:** This is a tenant setup issue. Refer to the stsstack / serverstack / prodstack onboarding docs for the user's environment. The runner cannot proceed without these.

### Zaza VIP allocation failure
**Symptom:** `create_zaza_vip` errors — usually a networking/port-create failure from `openstack port create`.
**Cause:** Exhausted VIPs in the subnet or quota issues.
**Fix:** `openstack port list --network net_${OS_USERNAME}-psd-extra` — check for orphaned ports from previous runs. Clean up with `openstack port delete`.

### Leftover `zaza-*` model from a previous run
**Symptom:** Deploy fails because the model name already exists, or the runner picks up an old model on `--rerun`.
**Cause:** A previous run was interrupted before cleanup.
**Fix:** `juju destroy-model zaza-<model-name> --force --no-wait --destroy-storage -y`. The runner tries `destroy_zaza_models` before each target, but if it can't (auth, stuck model), do it manually.

## Test phase failures

### Tests fail but deployment is fine
**Symptom:** `functest-test` exits non-zero; `juju status` shows all units `active/idle`.
**Cause:** zaza test or tempest scenario failure — the actual bug being tested, or a flaky test.
**Recovery:**
1. `--rerun test` to retry.
2. For intermittent failures, `--manual-functests` to control each phase.
3. Read the zaza log: it usually prints the Python traceback inline. Also check `juju debug-log --replay` on the model.

### `functest-configure` fails
**Symptom:** Configure phase errors; model exists but apps aren't configured.
**Cause:** Usually a missing relation, wrong charm config, or a timeout waiting for units.
**Recovery:** `juju status` to inspect; fix manually, then `--rerun configure` or `--rerun test`.

## Model & environment issues

### Wrong Juju version
**Symptom:** Model creation fails with API incompatibility or "unknown feature flag".
**Cause:** The runner exports `TEST_JUJU3=1` and uses a Juju 3.6 constraints file unless Juju is 2.9. If you're on Juju 2.x (not 2.9) or an old 3.x, things may break.
**Fix:** `sudo snap refresh juju --channel 3.6/stable` (or whatever OSCI uses for this charm).

### `identify_charm_func_test_jobs.py` returns nothing
**Symptom:** No targets found; runner does nothing.
**Cause:** `osci.yaml` is missing, malformed, or uses a non-standard schema.
**Fix:** Check `osci.yaml` exists at the charm root. For source-form charms it may be at `src/osci.yaml` — verify. If it truly doesn't exist, the charm may not use the zaza flow (see `references/discover-targets.md`).

## Voting vs non-voting

Non-voting targets are listed under `check:` but not `gate:` in `osci.yaml`. The runner always runs them after voting targets. A non-voting failure is informational — it doesn't block merges in CI. The final report annotates each target with `(non-voting)` when applicable.

If the user is only interested in gate-blocking results, filter to voting targets: run `test_is_voting.py <target>` for each candidate and only pass the `True` ones via `--func-test-target`.
