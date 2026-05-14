# Discovering `--func-test-target` values

The runner resolves targets from the charm's `osci.yaml` (at the charm root) using helper scripts in
`openstack/tools/func_test_tools/`.

## The lookup chain

1. **`osci.yaml`** — the CI definition. Lists test "jobs", each with a target name. Example excerpt:

   ```yaml
   - project:
       templates:
         - charm-unit-jobs-py310
       vars:
         needs_charm_build: true
         charm_build_name: nova-compute
         build_type: charmcraft
         charmcraft_channel: 2.x/stable
       check:
         jobs:
           - focal-xena-func-test
           - jammy-yoga-func-test
           - jammy-antelope-func-test
           - jammy-caracal-func-test
       gate:
         jobs:
           - focal-xena-func-test
           - jammy-yoga-func-test
   ```

   Target names here are entries like `focal-xena-func-test`, `jammy-yoga-func-test`, etc.

2. **`identify_charm_func_test_jobs.py`** (`func_test_tools/`) — parses `osci.yaml`, emits
   one target name per line. The runner calls this when no `--func-test-target` is passed.
   You can call it directly:

   ```bash
   python3 <stsstack-bundles>/openstack/tools/func_test_tools/identify_charm_func_test_jobs.py
   ```

   Run it from the charm root (it reads `osci.yaml` from `$PWD`).

3. **`extract_job_target.py`** (`func_test_tools/`) — given a target name, returns the
   bundle/config name the zaza runner uses. The runner calls this internally:

   ```bash
   python3 <stsstack-bundles>/openstack/tools/func_test_tools/extract_job_target.py <target-name>
   ```

   The output is what gets passed to `tox -e func-target -- <output>`.

4. **`test_is_voting.py`** (`func_test_tools/`) — given a target, returns `True` if it's voting
   (i.e. it's listed under `gate:` in `osci.yaml`), `False` if non-voting (only in `check:`).

   ```bash
   python3 <stsstack-bundles>/openstack/tools/func_test_tools/test_is_voting.py <target-name>
   ```

## From target name to test bundle

The bundle that gets deployed lives in:

- `tests/bundles/<bundle-name>.yaml` (classic layout)
- `src/tests/bundles/<bundle-name>.yaml` (source-form charms where the `src/` directory holds the Python source)

The relationship between a target name and a bundle name depends on the charm's `tests/tests.yaml`
(or `src/tests/tests.yaml`) — that file lists the zaza test configuration:

```yaml
charm_name: nova-compute
gate_bundles:
  - focal-xena
  - jammy-yoga
smoke_bundles:
  - jammy-caracal
configure:
  - zaza.openstack.charm_tests.nova.tests.NovaCompute...
tests:
  - zaza.openstack.charm_tests.nova.tests.NovaCompute...
```

The bundle filename (minus `.yaml`) is what the `extract_job_target.py` output maps to.

## Finding the right target when the user gives you a test class / tempest test

1. Grep the `tests/tests.yaml` (or `src/tests/tests.yaml`) for the test class or tempest selector.
2. Check which bundle that test class is associated with.
3. Cross-reference with `osci.yaml` targets to find the matching `--func-test-target` name.

Example: user says "I need the target that runs `NovaCompute` tests on `jammy-caracal`"
→ `tests/tests.yaml` shows `jammy-caracal` is a bundle → `osci.yaml` has `jammy-caracal-func-test` → use `--func-test-target jammy-caracal-func-test`.

## When the charm has no `osci.yaml`

Some very old or out-of-tree charms don't have `osci.yaml`. In that case:

- Check for `tests/tests.yaml` / `src/tests/tests.yaml` directly.
- Look for `tox.ini` `[testenv:func]` or `[testenv:func-target]` entries.
- If none exist, the charm likely doesn't use zaza — **stop and tell the user**. Don't fabricate a target.
