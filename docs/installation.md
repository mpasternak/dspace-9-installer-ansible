# Installation

## Prerequisites

**Control machine** (where you run `make`):

- Ansible 2.9+ (installed automatically by `configure-developer-machine`)
- An SSH client and Python 3
- Provider tooling as needed (Tart, OrbStack, Vagrant…) — see [Providers](providers.md)

**Target host:**

- Ubuntu 20.04+ or Debian-based Linux
- SSH access with sudo (passwordless, by convention)
- ≥ 4 GB RAM (8 GB recommended), 20 GB+ free disk, internet access

## Full stack in one go

```bash
make build-vm install-complete
```

`install-complete` runs three phases:

1. `install-prerequisites` — Java, PostgreSQL, Solr, Tomcat, nginx (+ the host firewall)
2. `install-dspace` — download, build (Maven/Ant), deploy the backend, create the admin
3. `install-frontend` — Angular UI, Node/PM2, nginx reverse proxy

Backend-only:

```bash
make install-dspace-all      # prerequisites + backend, no frontend
```

## Step by step

If you'd rather run phases individually (useful for debugging or re-runs):

```bash
make install-prerequisites          # Java / PostgreSQL / Solr / Tomcat / nginx / ufw
make install-dspace                 # backend (download + build + install + admin)
make install-frontend               # Angular frontend

# Backend, broken down further:
make dspace-download                # fetch source
make dspace-build                   # Maven + Ant
make dspace-install-only            # install from a built tree
make dspace-rebuild                 # rebuild + reinstall (skip download)

# Frontend, broken down further:
make install-frontend-prerequisites # Node.js, PM2, build tools
make install-frontend-download
make install-frontend-config
make install-frontend-build
```

!!! tip "If a step fails partway"
    The installer prints the exact command to resume from the failed task
    (`--start-at-task=...`). See [Operations → Resuming a failed run](operations.md#resuming-a-failed-run).

## Choosing a version

```bash
# A specific released version
make dspace-version VERSION=9.1
make frontend-version VERSION=9.1

# A GitHub branch
make dspace-github BRANCH=main
make frontend-github BRANCH=dspace-9_x
```

Or pin `dspace_version` in `ansible/group_vars/all.yml` (see [Configuration](configuration.md)).

## Optional: Handle server

```bash
make install-handles-server
```

Runs a Handle.Net server as a systemd service for persistent identifiers.

## After installing

- Set the public access URL: [`make set-access-url URL=...`](configuration.md#access-url)
- Open the UI: `make open-browser`
- Log in with `admin@localhost` / `admin`
