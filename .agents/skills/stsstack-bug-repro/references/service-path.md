# Service-level path (step 4B)

Use this when the bug is in the OpenStack service code (not the charm) and you just need a representative cloud. stsstack-bundles' `openstack/` stack deploys it.

## 4B.1 — Map dimensions to flags/overlays

Read the repo every time — flags and overlays change. Read-only commands (no confirmation needed):

- `./generate-bundle.sh --help` — authoritative options
- `./generate-bundle.sh --list-overlays` — authoritative overlays
- File reads: `openstack/module_defaults`, `openstack/pipeline/02configure`, `openstack/overlays/`, root `overlays/`, `openstack/profiles/<name>`

### Flag syntax (confirmed from `--help`)

- **Overlays** are passed as `--<overlayname>`, NOT `--overlay <name>`. Example: `--vault --octavia --ha`.
- **HA-capable overlays** (marked with `*` in `--list-overlays`) accept unit count via colon: `--ha:3`, `--keystone-ha:3`, `--mysql-ha:3`.
- `--release <name>` / `-r` — OpenStack release as a **codename** (`caracal`, `epoxy`, `flamingo`, ...), not `yyyy.N`. Only meaningful on LTS Ubuntu (UCA pocket).
- `--series <name>` / `-s` — Ubuntu series.
- `--name <name>` / `-n` — bundle and Juju model name; also creates/switches model unless `--no-create-model`.
- `--run` — generate then `juju deploy` in one step.
- `--charmstore` — use cs: instead of ch: (legacy charms only).
- `--pocket <p>` / `-p` — archive pocket (e.g., `proposed`).
- Module opts (`--num-compute <int>`, `--neutron-fw-driver <...>`, etc.) — see MODULE OPTS section of `--help`.

Don't assume the existence of any other flag. If a knob is missing, say "no flag/overlay for X — would need a manual template/overlay edit" and stop. See `release-mapping.md` for the release/series mapping rules.

## 4B.2 — Produce the recipe

Use only flags/overlays you confirmed above. Keep it copy-pasteable.

```
## Reproduction summary
<one paragraph: which LP bug, what conditions are needed>

## Generate the bundle
cd openstack/
./generate-bundle.sh \
    --release <codename> --series <series> \
    --name <repro-name> \
    [--<overlay1> --<overlay2>:<units> ...] \
    [--num-compute <N> ...]

## Deploy
# generate-bundle.sh prints the exact deploy command(s) on completion — use those.
# (Or pass --run to combine generate + deploy.)
# Wait until `juju status` shows everything active/idle.

## Post-deploy configuration
./configure [profile] [net_type]

## Trigger
<exact commands the user must run to hit the bug>
# If the symptom is intermittent, loop the trigger N times.

## What to observe
<exact symptom — which command's output, which log line, which juju status field>

## Logs to collect if it fails to reproduce
- juju status --format=yaml > status.yaml
- juju debug-log --replay > debug.log
- juju ssh <unit> 'sudo tar czf - /var/log/<service>' > <unit>-logs.tar.gz
- <service-specific logs>
```

### Trigger patterns (service-level)

Match the bug's trigger to one of these shapes:

- **OpenStack CLI sequence** — `openstack server create ...`, `openstack loadbalancer create ...`
- **REST API call** — `curl -H "X-Auth-Token: $TOKEN" ...`
- **Charm config flip** — `juju config <app> <key>=<value>` then observe unit state
- **Unit restart / failover** — `juju ssh <unit> 'sudo systemctl restart <svc>'`, `juju run --unit <unit> -- ...`
- **Tempest / Rally** — usually from a controller or external node for service-level bugs
- **Web UI navigation** — open Horizon at `https://<openstack-dashboard-vip>/horizon`, perform the action, capture the browser DevTools error and the apache/horizon logs from the openstack-dashboard unit (`/var/log/apache2/error.log`, `/var/log/apache2/openstack-dashboard.log`)
- **Intermittent** — loop N times

## 4B.3 — Assumptions and gaps

End the recipe with:

- **Assumed**: anything inferred but not in the bug (e.g., "assumed `noble` since release is Caracal")
- **Needs the user to decide**: substrate (MAAS vs LXD), profile, anything depending on their environment
- **Couldn't determine**: things truly missing from the input

## 4B.4 — Verify

See `SKILL.md` step 5.
