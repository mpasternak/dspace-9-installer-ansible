# Design: OrbStack + `local-linux` Providers

**Date:** 2026-06-03
**Status:** Approved

## Goal

Add two new deployment providers to the existing provider-agnostic abstraction:

1. **`orbstack`** — deploy DSpace into a full OrbStack Linux machine on macOS
   (direct parallel to the existing Tart provider).
2. **`local-linux`** — "loopback" provider that installs DSpace directly onto the
   Linux machine running `make`, using Ansible's `local` connection (no VM, no SSH).

Both are purely additive. They follow the established provider contract, so no
Ansible role and no target in the main `Makefile` changes.

## Provider contract (existing)

Each provider lives in `providers/<name>.mk` and implements:

- `provider-init`, `provider-start`, `provider-stop`, `provider-destroy`
- `provider-ssh`, `provider-get-ip`, `provider-status`
- `provider-copy-ssh-key`, `provider-install-deps`

…plus an Ansible inventory at `ansible/inventory/<name>.ini`. Selection is via
`PROVIDER=<name>`. `config.mk` keeps `PROVIDER ?= tart` (explicit-only — no
auto-default on Linux, by decision).

## Provider 1: `orbstack` (macOS host)

OrbStack 2.1.3 facts (verified on the dev machine):

- `orbctl create DISTRO[:VERSION] [NAME]` — e.g. `orbctl create ubuntu:noble dspace-server`.
- `orbctl start|stop|delete NAME`; `orbctl list` (text; last column is the IP) and
  `orbctl list -f json`; `orbctl info NAME -f json`.
- Default Linux user = the macOS username, with **passwordless sudo**.
- SSH is via the auto-generated `Host orb` block (`~/.orbstack/ssh/config`,
  included from `~/.ssh/config`). User syntax: `<machine>@orb` (default user) or
  `<user>@<machine>@orb`. OrbStack manages the keys — **no key copy needed**.
- Machines share host resources dynamically — no CPU/RAM/disk sizing step.

### Targets

| Target | Implementation |
|---|---|
| `provider-init` | Error if `$(VM_NAME)` already exists; else `orbctl create $(ORBSTACK_IMAGE) $(VM_NAME)`. Wait until it appears `running`. |
| `provider-start` / `provider-stop` | `orbctl start` / `orbctl stop $(VM_NAME)` |
| `provider-destroy` | Confirm (yes/no) → `orbctl delete $(VM_NAME)` |
| `provider-ssh` | `ssh $(VM_NAME)@orb` |
| `provider-get-ip` | IP from `orbctl info $(VM_NAME) -f json` (fallback: parse `orbctl list`) |
| `provider-status` | Read machine state from `orbctl list` |
| `provider-copy-ssh-key` | No-op — OrbStack manages keys (info message only) |
| `provider-install-deps` | Verify `orbctl`; else point to `brew install orbstack` |

Variable: `ORBSTACK_IMAGE ?= ubuntu:noble` (Ubuntu 24.04, matching the Docker
provider's `ubuntu:24.04`).

### Inventory `ansible/inventory/orbstack.ini`

```ini
[dspace_servers]
dspace-server ansible_host=orb ansible_user=dspace-server ansible_python_interpreter=/usr/bin/python3
```

`ansible_user=dspace-server` is the **machine name**, which under OrbStack's
`<machine>@orb` syntax logs into the default user (passwordless sudo). Roles'
`become: true` then escalate to root as usual. A comment in the file explains
this non-obvious mapping.

**Connection decision:** use the `<machine>@orb` SSH proxy (zero-config,
OrbStack-managed keys, works with stock Ansible) rather than a custom `orb -m`
exec connection or `.orb.local` direct SSH.

## Provider 2: `local-linux` (Linux host, loopback)

Installs onto the machine running `make`, via `ansible_connection=local`.

### Inventory `ansible/inventory/local-linux.ini`

```ini
[dspace_servers]
dspace-server ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

### Targets

| Target | Implementation |
|---|---|
| `provider-install-deps` | **OS guard:** error clearly if `uname -s` ≠ `Linux` or `apt-get` missing. (This is why the provider is named `local-linux` — on macOS it refuses rather than half-running.) |
| `provider-init` | Re-run OS guard; check **passwordless sudo** (`sudo -n true`) and exit with sudoers instructions if missing; print a one-line "this modifies the local machine" notice. |
| `provider-start` / `provider-stop` | No-op (informational — "you are the host") |
| `provider-destroy` | No-op + manual-cleanup hint (mirrors the SSH provider) |
| `provider-ssh` | Launch a local shell |
| `provider-get-ip` | `127.0.0.1` |
| `provider-status` | Local hostname / OS / memory / CPU count |
| `provider-copy-ssh-key` | No-op (local connection) |

**Sudo decision:** require passwordless sudo (checked in `provider-init`) instead
of threading `--ask-become-pass` through every `ansible-playbook` line in the main
Makefile. Keeps the main Makefile untouched and matches the existing convention
(every other provider relies on an `admin NOPASSWD` user).

**Caveat to document:** `make build-vm` runs `update-system.yml`, which can
auto-reboot. On `local-linux` that reboots the local machine — acceptable because
the loopback target is meant to be a dedicated server, but flagged prominently in
the README.

## `config.mk`

Only the provider-list comment is updated to include `orbstack` and `local-linux`.
`PROVIDER ?= tart` is unchanged.

## Documentation

- **README.md** — add both providers to the provider sections with quick-start
  examples, the macOS-only / Linux-only notes, and the reboot caveat.
- **CLAUDE.md** — update the provider list in the dev reference for consistency.

## Testing

- **`orbstack`** — live smoke test on the dev machine: create a throwaway
  `dspace-server` machine, `ansible -m ping`, verify `become` (sudo) works,
  then `orbctl delete`.
- **`local-linux`** — verify the OS guard correctly *refuses* on macOS and lint
  the Makefile/inventory syntax. A full install run is only meaningful on an
  actual Linux host.

## Out of scope

- No `/etc/hosts` management for either provider (OrbStack machines resolve via
  `.orb.local`; `local-linux` is reachable at localhost).
- No change to `domain_name` handling or nginx config.
