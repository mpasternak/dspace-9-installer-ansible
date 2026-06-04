# Reference

## Make targets

All targets work with any provider. Set the provider with `PROVIDER=` or in
`config.mk`. Run `make help` for the live list.

### Setup & configuration

| Target | Description |
|--------|-------------|
| `configure-developer-machine` | Install dependencies and create the VM/host |
| `build-vm` / `configure-host` | Create the VM or validate the SSH host |
| `ssh-copy-id` | Copy SSH keys to the VM/host |
| `set-access-url URL=…` | Point backend + frontend at a public URL |
| `hosts-add` / `hosts-check` / `hosts-remove` | Manage the `/etc/hosts` entry (Tart) |

### VM / host management

| Target | Description |
|--------|-------------|
| `start-vm` / `stop-vm` / `destroy-vm` | Lifecycle (no-op for SSH/local-linux) |
| `vm-status` | Provider/host status |
| `ssh` | Open a shell on the target |
| `provider-exec REMOTE_CMD=…` | Run a command on the target |
| `open-browser` / `open-api` / `open-solr` | Open the UI / API / Solr in a browser |

### Installation

| Target | Description |
|--------|-------------|
| `install-prerequisites` | Java, PostgreSQL, Solr, Tomcat, nginx, firewall |
| `install-dspace` | Backend (download + build + install + admin) |
| `install-frontend` | Angular frontend |
| `install-complete` | Backend + frontend + nginx |
| `install-dspace-all` | Prerequisites + backend (no frontend) |
| `install-handles-server` | Optional Handle server |
| `dspace-download` / `dspace-build` / `dspace-install-only` / `dspace-rebuild` | Backend phases |
| `dspace-version VERSION=…` / `dspace-github BRANCH=…` | Version selection |
| `frontend-version VERSION=…` / `frontend-github BRANCH=…` | Frontend version selection |

### Maintenance & operations

| Target | Description |
|--------|-------------|
| `update-apt` | Update OS packages via Ansible |
| `check-services` | Status of postgresql / tomcat / solr |
| `tail-logs` | Follow backend logs (`LOG_FILE=`, `LINES=`) |
| `frontend-logs` / `frontend-restart` / `frontend-status` | Frontend operations |
| `backup-db` | `pg_dump` the database |
| `migrate-plan EXISTING=…` | Preview a same-host migration |
| `migrate-from EXISTING=…` | Migrate a legacy install (resumable) |
| `clean-logs` / `clean` | Housekeeping |

## Ansible playbooks

Run directly against any inventory if you prefer:

| Playbook | Purpose |
|----------|---------|
| `update-system.yml` | Update apt packages (may reboot) |
| `install-prerequisites.yml` | Java, PostgreSQL, Solr, Tomcat, nginx, ufw |
| `install-dspace.yml` | Full backend |
| `install-frontend.yml` | Full frontend |
| `install-handles-server.yml` | Handle server |
| `set-access-url.yml` | Re-point a running install at a URL |
| `migrate-local.yml` | Same-host legacy → repo install migration |
| `dspace-download.yml` / `dspace-build.yml` / `dspace-install-only.yml` | Backend phases |

## Stack components

| Component | Version / detail |
|-----------|------------------|
| Java | OpenJDK 17 |
| PostgreSQL | 16 |
| Apache Solr | 9.10.1 |
| Apache Tomcat | 10.1.33 (backend webapp on :8080) |
| Node.js | 20 LTS (frontend, PM2 cluster) |
| Web server | nginx (reverse proxy) |

## Key paths (on the target)

| Path | What |
|------|------|
| `/opt/dspace` | DSpace home (CLI at `bin/dspace`, config in `config/local.cfg`) |
| `/opt/dspace/assetstore` | Bitstreams |
| `/opt/tomcat` | Tomcat (logs in `logs/catalina.out`) |
| `/var/solr/data` | Solr cores (incl. `statistics`) |
| PostgreSQL `dspace` | Database (role `dspace`) |

## Project structure

```
.
├── Makefile                 # provider-agnostic orchestrator
├── config.mk                # provider selection + common config
├── mkdocs.yml               # this documentation site
├── providers/               # tart, orbstack, vagrant, ssh, docker, local-linux
└── ansible/
    ├── inventory/           # one .ini per provider
    ├── group_vars/all.yml   # global variables
    ├── callback_plugins/    # resume_hint.py
    ├── roles/               # java, postgresql, solr, tomcat, nginx, ufw,
    │                        #   certbot, swap, dspace*, dspace-frontend, firefox
    └── *.yml                # playbooks
```

## Links

- [DSpace 9 Documentation](https://wiki.lyrasis.org/display/DSDOC9x)
- [GitHub repository](https://github.com/mpasternak/dspace-9-installer-ansible)
