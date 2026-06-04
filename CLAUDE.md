# DSpace 9 Installer - Development Framework

## Overview
This project provides a **provider-agnostic automation framework** for deploying DSpace 9 (digital repository software) to various targets including local VMs, cloud servers, and physical machines. It uses Ansible for configuration management and supports multiple virtualization providers through a clean abstraction layer.

## Key Features
- **Multi-provider support**: Tart (macOS), OrbStack (macOS), Vagrant (cross-platform), SSH (direct), Docker (CI/CD), local-linux (loopback)
- **Complete DSpace stack**: Automated installation of backend, frontend, and all prerequisites
- **Version flexibility**: Deploy specific DSpace versions or build from GitHub branches
- **Unified interface**: Same Make commands work across all providers
- **CI/CD integration**: GitHub Actions workflow for automated testing

## Architecture

### System Components
```
┌──────────────────────────────────────┐
│        Control Machine               │
│  - Ansible orchestration            │
│  - Provider abstraction (Makefile)  │
│  - Configuration management         │
└─────────────┬────────────────────────┘
              │ SSH
              ▼
┌──────────────────────────────────────┐
│         Target Systems               │
│  - Tart VM (macOS native)           │
│  - Vagrant VM (VirtualBox/VMware)   │
│  - Docker container (CI testing)    │
│  - Physical/Cloud servers (SSH)     │
└──────────────────────────────────────┘
```

### DSpace Stack
- **Backend**: Java 21, PostgreSQL 16, Apache Solr 9.10.1, Apache Tomcat 10.1.55
- **Frontend**: Angular UI with Node.js 20 LTS, PM2 process manager
- **Web Server**: Nginx with reverse proxy configuration
- **Optional**: Handles server for persistent identifiers

## Project Structure
```
.
├── Makefile                    # Main orchestrator (provider-agnostic)
├── config.mk                   # Provider selection & configuration
├── providers/                  # Provider implementations
│   ├── tart.mk                # macOS native virtualization
│   ├── orbstack.mk            # OrbStack Linux machines (macOS)
│   ├── vagrant.mk             # Cross-platform VM support
│   ├── ssh.mk                 # Direct SSH connections
│   ├── docker.mk              # Docker for CI/CD testing
│   └── local-linux.mk        # Local Linux loopback (install on self)
├── ansible/                    # Configuration management
│   ├── inventory/             # Provider-specific inventories
│   │   ├── tart.ini          # Dynamic Tart inventory
│   │   ├── orbstack.ini      # OrbStack inventory (<machine>@orb)
│   │   ├── vagrant.ini       # Dynamic Vagrant inventory
│   │   ├── ssh.ini           # SSH hosts inventory
│   │   ├── docker.ini        # Docker inventory
│   │   └── local-linux.ini   # Local loopback (ansible_connection=local)
│   ├── group_vars/
│   │   └── all.yml           # Global variables (versions, paths, etc.)
│   ├── callback_plugins/    # resume_hint.py (friendly resume-on-failure hint)
│   ├── roles/                # Modular Ansible roles
│   │   ├── dspace-base/      # DSpace base setup
│   │   ├── dspace/           # DSpace core config (local.cfg)
│   │   ├── dspace-download/  # Source download
│   │   ├── dspace-build/     # Maven/Ant build
│   │   ├── dspace-install/   # Install + admin account
│   │   ├── dspace-frontend/  # Angular UI + PM2
│   │   ├── java/             # Java installation
│   │   ├── postgresql/       # Database setup
│   │   ├── solr/             # Search engine setup
│   │   ├── tomcat/           # Application server
│   │   ├── nginx/            # Web server & reverse proxy
│   │   ├── certbot/          # SSL certificates (Let's Encrypt)
│   │   ├── ufw/              # Host firewall (UFW)
│   │   ├── firefox/          # Firefox browser (for testing)
│   │   └── swap/             # Swap configuration
│   └── playbooks/
│       ├── install-prerequisites.yml   # Install stack components
│       ├── install-dspace.yml         # Complete backend installation
│       ├── install-frontend.yml       # Complete frontend installation
│       ├── install-handles-server.yml # Optional handles server
│       ├── update-system.yml          # System updates with auto-reboot
│       └── remove-frontend.yml        # Clean frontend removal
├── .github/workflows/
│   └── test-docker-installation.yml   # CI/CD pipeline
├── README.md                   # User documentation
├── MIGRATION.md               # Migration guide for provider changes
└── CLAUDE.md                  # This file (developer reference)
```

## Common Workflows

### Quick Installation (Default Provider - Tart)
```bash
# Complete stack with frontend
make build-vm install-complete

# Backend only
make build-vm install-dspace-all

# Access the installation
make ssh
```

### Provider-Specific Usage
```bash
# Vagrant
PROVIDER=vagrant make build-vm install-complete

# SSH to existing server
PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host install-complete

# Docker (mainly for CI)
PROVIDER=docker make build-vm install-complete

# OrbStack (macOS Linux machine)
PROVIDER=orbstack make build-vm install-complete

# local-linux (loopback — install onto this Linux machine)
PROVIDER=local-linux make build-vm install-complete
```

### Version Management
```bash
# Specific DSpace version
make dspace-version VERSION=9.3
make frontend-version VERSION=9.3

# GitHub branches
make dspace-github BRANCH=main
make frontend-github BRANCH=dspace-9_x
```

## Key Make Targets

### Setup & Configuration
- `configure-developer-machine` - Install dependencies and initialize VM/host
- `build-vm` / `configure-host` - Create VM or validate SSH host
- `update-apt` - Update system packages via Ansible

### DSpace Installation
- `install-prerequisites` - Java, PostgreSQL, Solr, Tomcat
- `install-dspace` - Complete backend installation
- `install-frontend` - Angular UI installation
- `install-complete` - Full stack (backend + frontend + nginx)
- `install-handles-server` - Optional handles server

### Maintenance
- `check-services` - Status of all DSpace services
- `tail-logs` - Follow DSpace logs
- `backup-db` - Create database backup
- `frontend-restart` - Restart Angular UI
- `frontend-logs` - Follow PM2 logs live (Ctrl+C to stop)
- `remove-frontend` - Clean frontend removal

### Access (open in browser)
- `open-browser` - Open the frontend (`http://<host>/`)
- `open-api` - Open the backend (`http://<host>/server/`, REST/HAL browser)
- `open-solr` - Open Solr admin (`http://<host>:8983/solr/`)
- `set-access-url URL=...` - Re-point a running install at a public URL. Edits
  backend `local.cfg` (dspace.ui.url / dspace.server.url / CORS) + frontend
  `config.prod.yml` (`rest` ssl/host/port, now templated from `dspace_rest_*`),
  then restarts Tomcat + frontend. Playbook: `ansible/set-access-url.yml`.
  Browser/SSR/CORS must all agree on one URL or the UI shows "Service Unavailable".
- `migrate-plan EXISTING=/old/dspace` / `migrate-from EXISTING=...` - Migrate a
  **same-host live legacy** DSpace into this install (reads its `local.cfg` for DB
  name/assetstore, drops/restores the `dspace` DB, copies assetstore, `database
  migrate` + `index-discovery -b`, restarts). Plan mode is read-only; run mode is
  resumable via `START_AT="<step>"` (reuses the `resume_hint` callback) and gated
  by a confirm (`CONFIRM=yes` to skip). `WITH_STATS=1` also moves Solr statistics.
  Playbook: `ansible/migrate-local.yml`. See `docs/data-migration.md`.
- Host is resolved via the active provider's `provider-get-ip`; override with
  `URL=...`, `BROWSER_PATH=...`, `BROWSER_SCHEME=https`, or `SOLR_PORT=...`.
  Opener: `open` (macOS) / `xdg-open` (Linux) / `wslview` (WSL).

## Configuration Files

### Main Configuration
- `config.mk` - Provider selection, defaults to Tart
- `ansible/group_vars/all.yml` - DSpace versions, paths, service configs
- `ansible/ansible.cfg` - Ansible behavior settings

### Key Variables (ansible/group_vars/all.yml)
```yaml
dspace_version: "10.0"
dspace_install_dir: "/opt/dspace"
postgres_version: "16"
java_version: "21"
solr_version: "9.10.1"
tomcat_version: "10.1.55"
nodejs_version: "20"
domain_name: "dspace-server.localnet"
ssl_enabled: false
# Firewall (UFW) — applied by the ufw role during install-prerequisites
firewall_enabled: true        # set false to skip firewall configuration
firewall_mode: "development"  # production | development | all
# Frontend REST endpoint (browser + SSR target); overridden by set-access-url
dspace_rest_ssl: "{{ ssl_enabled }}"
dspace_rest_host: "{{ domain_name }}"
dspace_rest_port: "{{ 443 if ssl_enabled | bool else 80 }}"
```

### Firewall (UFW)
- `roles/ufw/` configures the host firewall, wired into `install-prerequisites`.
- Always-open: SSH 22, HTTP 80, HTTPS 443, Handle 2641. `development` mode also
  opens Tomcat 8080/8000 + frontend 4000; `all` mode also opens Solr 8983 +
  PostgreSQL 5432 (debug). Controlled by `firewall_enabled` / `firewall_mode` /
  `ufw_default_*` in `group_vars/all.yml`.

## Provider Details

### Tart (Default - macOS)
- Native macOS virtualization (M1/M2/Intel)
- Lightweight, fast VM creation
- Dynamic inventory via `tart ip` command
- Automatic /etc/hosts management

### OrbStack (macOS)
- Fast, lightweight Linux machines on macOS (https://orbstack.dev)
- Managed with `orbctl` (alias `orb`); created via `orbctl create $(ORBSTACK_IMAGE) $(VM_NAME)` (default `ubuntu:noble`)
- SSH via OrbStack's auto-generated `orb` host: `ssh <machine>@orb`
- Inventory uses `ansible_host=orb` with `ansible_user=<machine name>` (OrbStack's `<machine>@orb` syntax → default user with passwordless sudo)
- OrbStack manages SSH keys (no key copy) and shares host resources dynamically (no CPU/RAM sizing)

### Vagrant (Cross-platform)
- Works on Windows, macOS, Linux
- VirtualBox or VMware backend
- Configurable resources (CPU, RAM)
- Port forwarding support

### SSH (Production)
- Direct connection to any Ubuntu/Debian host
- Works with cloud providers (AWS, Azure, GCP, DigitalOcean)
- No VM management overhead
- Requires sudo access

### Docker (CI/CD)
- Used for GitHub Actions testing
- Ubuntu 24.04 base image
- Systemd support for services
- Automated testing pipeline

### local-linux (Loopback)
- Installs DSpace onto the machine running `make`, via `ansible_connection=local` (no VM, no SSH)
- Debian/Ubuntu Linux hosts only — refuses to run on macOS (hence the `-linux` suffix); guard in `provider-install-deps`/`provider-init` checks `uname -s` and `apt-get`
- Requires passwordless sudo for the current user (checked in `provider-init`); matches the `admin NOPASSWD` convention of the other providers
- `start-vm`/`stop-vm`/`destroy-vm` are no-ops; `get-ip` returns `127.0.0.1`
- ⚠️ `build-vm` runs `update-system.yml`, which may upgrade packages and reboot the host — intended for a dedicated target machine

## CI/CD Pipeline
- **Workflow**: `.github/workflows/test-docker-installation.yml`
- **Badge**: Shows build status in README
- **Tests**: Complete installation including frontend
- **Provider**: Docker with SSH access
- **Schedule**: Runs on push to main branch

## Development Notes

### SSH Access
```bash
# Default credentials (VMs)
Username: admin
Password: admin

# SSH to target
make ssh

# Direct SSH (for debugging)
ssh admin@$(tart ip dspace-server)  # Tart
vagrant ssh                          # Vagrant
ssh user@host                        # SSH provider
```

### Service Management
- PostgreSQL: `systemctl status postgresql`
- Tomcat: `systemctl status tomcat`
- Solr: `systemctl status solr`
- Frontend: PM2 manages Node.js process
- Nginx: `systemctl status nginx`

### File Locations
- DSpace installation: `/opt/dspace` (symlink to versioned dir)
- Source code: `/opt/dspace-src` (symlink to versioned dir)
- Frontend source: `/opt/dspace-angular-src-{version}`
- Frontend app: `/opt/dspace-angular`
- Logs: `/opt/dspace/log/`, `/var/log/tomcat/`, `/var/log/pm2/`

### Frontend Architecture
- Separate user (`dspaceui`) from backend (`dspace`)
- PM2 process manager for production deployment
- Cluster mode with configurable instances
- Systemd integration via `dspace-frontend.service`
- Nginx reverse proxy to port 4000

### Database Access
```bash
# Connect to database
sudo -u postgres psql -d dspace

# Backup database
make backup-db
```

## Testing & Verification

### URLs
- Frontend UI: `http://dspace-server/`
- Backend API: `http://dspace-server/server/api`
- Solr Admin: `http://dspace-server:8983/solr`

### Default Admin Credentials
- Email: `admin@localhost`
- Password: `admin`

## Troubleshooting

### Common Issues
1. **Build failures**: Check Maven memory settings in `group_vars/all.yml`
2. **Port conflicts**: Ensure ports 8080, 8983, 4000 are free
3. **VM issues**: Use `make destroy-vm` and rebuild
4. **Frontend build slow**: Normal, takes 10-15 minutes
5. **SSL issues**: Check domain_name and certbot settings

### Debug Commands
```bash
# Verbose Ansible output
ANSIBLE_VERBOSE=-vvv make install-dspace

# Check service status
make check-services

# View logs
make tail-logs         # Backend
make frontend-logs     # Frontend
```

### Resuming a Failed Run
- On any failed Ansible run, the `resume_hint` callback plugin
  (`ansible/callback_plugins/resume_hint.py`, enabled via `ansible.cfg`) prints
  the failed task name plus a ready-to-paste `--start-at-task=...` command after
  the play recap.
- `--start-at-task` matches the bare task name or the `role : task` form (see
  `play_iterator.py`). Resuming is safe only when the task doesn't rely on
  variables/facts registered by earlier (now-skipped) tasks; otherwise re-run
  the whole idempotent playbook. The hint shows both commands.

## Important Considerations
- Minimum 4GB RAM (8GB recommended) for target systems
- Frontend build requires significant resources
- First installation downloads ~2GB of dependencies
- SSL requires valid domain name for Let's Encrypt
- Development uses self-signed certificates by default

## Links
- [DSpace Documentation](https://wiki.lyrasis.org/display/DSDOC9x)
- [GitHub Repository](https://github.com/mpasternak/dspace-installer)
- [DSpace Community](https://duraspace.org/dspace/)