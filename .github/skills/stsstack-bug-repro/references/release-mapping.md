# Release ↔ series mapping

`common/openstack_release_info` in this repo is the **local ground truth** for what stsstack-bundles can deploy.

## Structure

```bash
declare -A lts=( [jammy]=yoga [noble]=caracal ... )           # Ubuntu LTS ↔ contemporaneous OpenStack
declare -A nonlts=( [plucky]=epoxy [questing]=flamingo ... )  # non-LTS Ubuntu ↔ OpenStack
declare -A os_release_map=( [2023.1]=antelope [2024.1]=caracal ... )  # yyyy.N → codename
declare -a lts_releases_sorted=( caracal yoga ussuri ... )    # ordered list of LTS-supported codenames
```

## Use

- **Convert yyyy.N → codename** (for `--release`): look up `os_release_map[<yyyy.N>]`.
- **Find Ubuntu series for a codename**: search `lts` and `nonlts` for the value, return the key.
- **`--release` always takes a codename** (`caracal`, `epoxy`, `flamingo`), not yyyy.N. Only meaningful on LTS Ubuntu (UCA pocket).

## Fallback when the bug's release isn't in the map

If the release in the bug (or the current dev release from releases.openstack.org) is **not present** in `openstack_release_info`, stsstack-bundles can't deploy it directly via `--release`. Two options:

1. **Fall back to the most recent supported release** — the last entry in `nonlts` or `lts_releases_sorted` — and note the deviation in the recipe. Reasonable when the bug isn't release-specific.
2. **Ask the user** before proceeding — when the bug is plausibly release-specific (e.g., upgrade-path bug, new-feature bug).

Don't silently substitute.

## Why this matters

releases.openstack.org tells us what *upstream OpenStack* knows about. `common/openstack_release_info` tells us what *this tool* can drive. The two can diverge (this tool lags behind upstream by a cycle or two). Always reconcile both before claiming a release is "supported".
