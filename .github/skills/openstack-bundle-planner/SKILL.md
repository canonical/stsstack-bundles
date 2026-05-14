---
name: openstack-bundle-planner
description: "Use when planning, generating, or operating an OpenStack bundle workflow in openstack/, including selecting overlays, release/series, model naming, writing and running the exact generate-bundle.sh command, interpreting post-deploy steps, and interacting with a deployed and configured model on behalf of the user."
---

# OpenStack Bundle Planner

Use this skill when the task is to design, adjust, generate, or operate an OpenStack deployment through the bundle-generator workflow in `openstack/`.

## Goal

Turn deployment intent into a concrete `./generate-bundle.sh` invocation, generate the bundle when requested, explain what the rendered deployment will do, and continue through the immediate operator path until the user has a usable model or a precise blocker.

This is the broadest OpenStack workflow skill. Use it when the user wants one continuous assistant flow from planning to generation and then, if the model exists, interaction with the deployed and configured cloud.

## Scope

This skill covers all of the following when they are part of one continuous task:

- Choosing release, series, model naming, cloud target, constraints, and overlays.
- Reading `pipeline/02configure` to understand implicit overlay selection, defaults, and conflicts.
- Producing the exact `./generate-bundle.sh` command.
- Running bundle generation when requested and interpreting the generated post-deploy instructions.
- Explaining the handoff from generation to Juju deployment.
- Identifying the correct `./configure <profile>` follow-up.
- Interacting with the deployed and configured model through Juju, `openstack/novarc`, and the scripts in `openstack/tools/`.

This skill is not only for static planning. It should stay with the task through the generator-driven lifecycle when the user wants the agent to act, not just describe.

## Mental Model

The OpenStack path in this repo is generator-driven and phase-oriented:

1. Plan the deployment intent.
2. Convert that intent into generator options.
3. Run `openstack/generate-bundle.sh` to render bundle artifacts and deployment command files.
4. Deploy using the generated Juju command or `--run`, in the intended Juju model and cloud.
5. Bootstrap post-deploy requirements such as Vault and `./configure <profile>`.
6. Use `source openstack/novarc` and helper scripts to operate the overcloud.

The skill should always be explicit about which phase it is currently handling.

## Primary Inputs To Resolve

Resolve these inputs before finalizing a plan or command:

- Target OpenStack release.
- Ubuntu series.
- Model name and optional cloud name.
- Undercloud type and profile expectation.
- Networking mode and feature requirements such as OVN, OVS, DVR, BGP, Octavia, LDAP, SAML, Manila, or Ceph.
- HA or scale requirements.
- Whether the user wants only a plan, bundle generation, deployment, or live post-deploy interaction.

If some inputs are missing, make the smallest safe assumption set and label each assumption. If there are conflicting inputs, confirm with the user before proceeding. If there is no safe assumption, ask the user for clarification before proceeding.

## Workflow

### Phase 1: Plan The Deployment

1. Read the request for deployment intent: release, Ubuntu series, HA needs, storage, networking, overlays, and undercloud constraints.
2. Inspect `openstack/pipeline/02configure` for overlay dependencies, defaults, conflicts, and post-deploy messages.
3. Inspect the closest feature doc in `openstack/docs/` when the request mentions a specific capability such as OVN, DVR, Octavia, LDAP, Manila, or BGP.
4. Check `openstack/profiles/` if the request depends on a specific undercloud or profile-driven post-deploy behavior.
5. Produce the exact generator command, including `--name`, `--release`, `--series`, overlays, and `--run` only when deployment is actually requested.

### Phase 2: Generate The Bundle

1. If the user asked to generate the bundle, run the planner command from `openstack/`.
2. Read the generator output for rendered overlays, bundle location, deploy command, and post-deploy actions.
3. Confirm whether generation succeeded cleanly or failed due to unrendered variables, option conflicts, or missing prerequisites.
4. If generation fails, diagnose at the generator-input level rather than editing rendered output first.

### Phase 3: Handoff To Deployment

1. If the user requested deployment, use the deploy command written by the generator into the bundle state directory rather than reconstructing it by hand.
2. Check whether the request should use `./generate-bundle.sh --run` or a separate deploy step from the generated `command` file.
3. Be explicit that bundle generation and Juju deployment are separate phases, even when `--run` joins them.
4. Track the difference between the active Juju model, the generated bundle name, and the configured cloud target. If `--name` was used, confirm whether the generator also created or switched to that model.
5. When not using `--run`, explain that the rendered state directory contains the exact deploy command and rendered overlays, and prefer replaying that command over improvising a new one.
6. After deploy starts, validate with `juju status` in the intended model and identify whether the cloud is merely deploying, stalled, or ready for post-deploy bootstrap.
7. Do not describe the model as usable until the deploy has settled enough for Vault/bootstrap and profile configuration to begin.

### Phase 4: Bootstrap The New Model

1. Interpret the generator's post-deploy messages.
2. Identify whether Vault bootstrap is required.
3. Choose the correct `./configure <profile>` command for the undercloud.
4. State the prerequisites for `~/novarc`, active Juju model, SSL state, and expected networking side effects.

### Phase 5: Interact With The Configured Cloud

1. If the model is deployed and configured, switch from planning mode to operator mode.
2. Use Juju for model inspection and action execution.
3. Use `source openstack/novarc` before overcloud OpenStack CLI or helper-script operations.
4. Prefer repo-provided helper scripts for common tasks such as security groups, images, instances, projects, Octavia setup, and tests.
5. Keep undercloud and overcloud actions distinct at every step.

## Required Output

Return all of the following:

- The recommended `./generate-bundle.sh` command.
- The major overlays implied directly or indirectly by the request.
- The profile the operator should use with `./configure` after deployment.
- The expected next phase after the current one.
- A short post-deploy checklist.
- Any assumptions that materially affect the command.

When the task includes action rather than planning only, also return:

- What phase was executed.
- What artifact or model state was produced.
- The next concrete command or validation step.

## Guardrails

- Prefer generator inputs over editing rendered bundle files under `openstack/b/`.
- Distinguish explicit overlays from implicit overlays added in `pipeline/02configure`.
- Call out release-sensitive defaults, especially OVN becoming the default on newer releases.
- Do not claim a deployment is ready after `juju deploy`; include Vault, `configure`, and `novarc` steps.
- If the request is underspecified, make the smallest safe assumption set and label it.
- Be explicit about the credential boundary:
	undercloud operations usually depend on `~/novarc`, while overcloud operations use `openstack/novarc`.
- Do not suggest editing `common/generate_bundle_base` for OpenStack-specific behavior.
- Do not hand-edit generated bundles under `openstack/b/` as the primary fix path when the root cause is in overlays, profiles, or `pipeline/02configure`.
- Do not treat `./configure` as a harmless step; it can attach ports, create networks, upload images, and mutate cloud state.

## Execution Guidance

When the user asks the agent to act, follow this order:

1. Plan and explain the intended generator command.
2. Generate the bundle if requested.
3. Validate the rendered output, bundle state directory, or generated deploy command.
4. Deploy if explicitly requested, preferably using the generated command file or `--run` instead of reconstructing a `juju deploy` command manually.
5. Bootstrap the model if deployment completed.
6. Interact with the configured model only after credentials and services are ready.

The skill should avoid skipping straight to day-2 operations without confirming that generation, deployment, and bootstrap have occurred.

## Common Planning Anchors

- `openstack/generate-bundle.sh`
- `openstack/pipeline/00setup`
- `openstack/pipeline/02configure`
- `openstack/common/generate_bundle_base`
- `openstack/configure`
- `openstack/novarc`
- `openstack/tools/construct_novarc.sh`
- `openstack/docs/tutorial.md`
- `openstack/docs/*.md`
- `openstack/profiles/*`
- `.github/agents/stsstack-bundles.agent.md`

## Live-Model Interaction Anchors

Use these once the model exists and the user wants the agent to operate it:

- `openstack/tools/vault-unseal-and-authorise.sh`
- `openstack/tools/sec_groups.sh`
- `openstack/tools/upload_image.sh`
- `openstack/tools/instance_launch.sh`
- `openstack/tools/create_project.sh`
- `openstack/tools/delete_project.sh`
- `openstack/tools/configure_octavia.sh`
- `openstack/tools/charmed_openstack_functest_runner.sh`
- `openstack/tools/openstack_regression_tests_runner.sh`

## Useful Heuristics

- For support test clouds, bias toward reproducible commands and post-deploy validation over exhaustive customization.
- If storage is requested, check for Ceph-related overlays and whether hyperconverged behavior matters.
- If networking is requested, check whether OVN, OVS, DVR, or neutron-gateway behavior changes the topology.
- If the user asks for manual charm deployment steps, first confirm the bundle generator does not already model that feature.
- If the user wants to interact with the cloud after generation, verify whether the model is merely generated, actually deployed, or fully configured before recommending commands.
- Treat `--run` as a convenience flag, not as proof that the model is healthy.
- When moving into operator actions, start with a cheap validation such as `juju status` or `source openstack/novarc && openstack service list` before making larger changes.

## Escalation And Routing

This skill can stay with the task end-to-end, but if the work narrows into one phase for a prolonged period, it should lean on the matching specialist workflow:

- Post-deploy bootstrap heavy work: `openstack-post-deploy-bootstrap`
- Day-2 overcloud operation: `openstack-cloud-operations`
- Functional or regression testing: `openstack-charmed-functional-tests`
- Failure analysis: `openstack-deployment-troubleshooter`

Do not route away immediately just because the task entered deployment or operations. This planner skill is allowed to continue through generation and model interaction when the user wants one continuous workflow.
