# Charm types — scope rules

Charms come in three frameworks. This skill targets only **reactive**.

## reactive

- `charms.reactive` + `charm-helpers` source layer + interface layers.
- Hosted on opendev: `https://opendev.org/openstack/charm-<name>`.
- Used by VM-based OpenStack deployments (what stsstack-bundles deploys).
- **In scope.**

## ops (operator framework)

- `ops` Python library, single-class operator pattern.
- Mostly K8s-related charms: COS (Grafana/Prometheus/Loki), MicroK8s, identity-platform, `*-k8s` charms, Kubeflow.
- Hosted on GitHub (`canonical/`, `openstack-charmers/`) or charmhub directly.
- **Out of scope.** If the LP project is clearly an ops charm, reject per the SKILL.md "When NOT to use" list.

## legacy

- Very old format (pre-2014), no `metadata.yaml`, manually-managed hooks.
- Effectively gone for OpenStack components.
- **Out of scope** by virtue of irrelevance.

## Interpreting a missing `stable/<release>` branch in a reactive OpenStack charm

There are **three branch-naming styles** in the OpenStack charms ecosystem — and the same charm sometimes uses more than one over its history. Don't assume a policy.

1. **`stable/<openstack-codename>`** — `stable/yoga`, `stable/caracal`. Older OpenStack-service charms.
2. **`stable/<yyyy.N>`** — `stable/2024.1`. Newer OpenStack-service charms (post-codename retirement).
3. **`stable/<ubuntu-series>`** — `stable/jammy`, `stable/focal`. **Data/infra charms** that follow Ubuntu's release cadence rather than OpenStack's: `charm-mysql-innodb-cluster`, `charm-percona-cluster`, `charm-rabbitmq-server`, and similar. For these, the bug's OpenStack release maps to its contemporaneous Ubuntu LTS via `common/openstack_release_info` (`lts[]`).

The general pattern is one `stable/*` branch per OpenStack release — **including non-LTS** (e.g., `stable/xena`, `stable/wallaby`, `stable/2023.1`, `stable/2023.2`) — but the exact set varies per charm: some branch every release, some skip cycles, some have stopped branching recently. Always check actual branches:

```
git branch -r | grep stable | sort
```

If `stable/<bug-release>` is absent, decide by **activity**, not assumed policy. Run the activity heuristic (`git log --since "6 months ago" --oneline` per branch, also documented in `cross-branch.md` 8.4):

- **Master active, recent stable active** → reproduce on the closest existing branch (most recent `stable/*` ≤ bug's release, or `master` if none), and flag in the report that the bug's exact release has no dedicated branch.
- **Master active, all stables silent** → reproduce on `master`; backports may not be expected.
- **All silent (master + stables)** → the charm may be deprecated; ask the user before guessing a new repo URL. Don't assume an ops migration for OpenStack VM charms — that route is rare and applies to K8s charms.
