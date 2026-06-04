# DSpace 9 Installer

A **provider-agnostic automation framework** for deploying [DSpace 9](https://wiki.lyrasis.org/display/DSDOC9x)
to local VMs, cloud servers, and physical machines. It uses Ansible for
configuration management and a clean Makefile abstraction so the **same commands
work across every target**.

```bash
make build-vm install-complete     # build a VM and install the full stack
```

## Why

DSpace is non-trivial to stand up — Java, PostgreSQL, Solr, Tomcat, an Angular
SSR frontend behind nginx, and a pile of configuration. This project makes a
complete, repeatable install one command away, and lets you point it at whatever
target you have: a throwaway VM on your laptop, a CI container, or a production
server over SSH.

## Features

- **Multiple providers** — Tart (macOS), OrbStack (macOS), Vagrant (cross-platform), SSH (any Ubuntu/Debian host), Docker (CI), and `local-linux` (install onto the machine you're on). [See Providers →](providers.md)
- **Complete stack** — backend (Java 17, PostgreSQL 16, Solr, Tomcat 10) + Angular frontend (Node 20, PM2) + nginx, plus an optional Handle server.
- **One interface** — the same `make` targets regardless of provider.
- **Version flexibility** — pin a DSpace version or build from a GitHub branch.
- **Operational tooling** — live log following, browser shortcuts, access-URL
  reconfiguration, host firewall, and automated [data migration](data-migration.md).

## Architecture

```
┌──────────────────────────────────────┐
│        Control Machine               │
│  ┌────────────────────────────┐      │
│  │     Main Makefile          │      │
│  │  (provider-agnostic)       │      │
│  └──────────┬─────────────────┘      │
│  ┌──────────▼─────────────────┐      │
│  │    Provider abstraction    │      │
│  │ Tart · OrbStack · Vagrant  │      │
│  │ SSH · Docker · local-linux │      │
│  └──────────┬─────────────────┘      │
│  ┌──────────▼─────────────────┐      │
│  │          Ansible           │      │
│  └────────────────────────────┘      │
└──────────────┬───────────────────────┘
               │ (SSH / local)
               ▼
┌──────────────────────────────────────┐
│      Target: full DSpace 9 stack     │
│  PostgreSQL · Solr · Tomcat · nginx  │
│  Angular frontend (PM2)              │
└──────────────────────────────────────┘
```

## Where to next

<div class="grid cards" markdown>

- :material-rocket-launch: **[Quick Start](quickstart.md)** — install the full stack in three steps
- :material-server: **[Providers](providers.md)** — pick and configure your target
- :material-cog: **[Configuration](configuration.md)** — versions, access URL, firewall, SSL
- :material-wrench: **[Operations](operations.md)** — logs, backups, browser shortcuts
- :material-database-arrow-right: **[Data Migration](data-migration.md)** — move an existing install
- :material-lifebuoy: **[Troubleshooting](troubleshooting.md)** — when something's off

</div>

!!! note "Requirements"
    Targets need Ubuntu 20.04+ / Debian, ≥4 GB RAM (8 GB recommended), 20 GB+ disk.
    The first install downloads ~2 GB of dependencies and the frontend build takes 10–15 minutes.
