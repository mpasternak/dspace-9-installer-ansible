# DSpace 9 Installer

[![Test DSpace Installation (Docker)](https://github.com/mpasternak/dspace-9-installer-ansible/actions/workflows/test-docker-installation.yml/badge.svg)](https://github.com/mpasternak/dspace-9-installer-ansible/actions/workflows/test-docker-installation.yml)

> Provider-agnostic automation framework for installing DSpace 9 with support for Tart VMs, OrbStack machines, Vagrant, direct SSH hosts, and local Linux (loopback) installs

📖 **Full documentation: <https://mpasternak.github.io/dspace-9-installer-ansible/>**

## Overview

This project provides a flexible, provider-agnostic framework for deploying DSpace 9 to various targets. Whether you're using local VMs (Tart or OrbStack on macOS, or Vagrant cross-platform), deploying to physical servers and cloud instances via SSH, or installing directly onto the Linux machine you're already on (loopback), this framework handles it all with a consistent interface.

## TL;DR

Quick installation in 3 steps:

```bash
# 1. Build VM and install complete DSpace stack (backend + frontend + nginx)
make build-vm install-complete

# 2. Access your DSpace installation
#    Frontend: http://dspace-server/
#    Backend:  http://dspace-server/server/api

# 3. When done, clean up the VM
make destroy-vm
```

## Features

- **Multiple Provider Support**: Choose between Tart (macOS), OrbStack (macOS), Vagrant (cross-platform), direct SSH connections, or a local Linux loopback install
- **Provider Abstraction**: Clean separation between virtualization layer and DSpace operations
- **Ansible Automation**: Idempotent, repeatable deployments using Ansible playbooks
- **Complete DSpace Stack**: Automated installation of all prerequisites (Java, PostgreSQL, Solr, Tomcat)
- **Version Flexibility**: Deploy specific DSpace versions or build from GitHub branches
- **Unified Interface**: Same commands work across all providers with simple configuration changes

## Architecture

```
┌──────────────────────────────────────┐
│        Control Machine               │
│                                      │
│  ┌────────────────────────────┐      │
│  │     Main Makefile          │      │
│  │  (Provider-agnostic)       │      │
│  └──────────┬─────────────────┘      │
│             │                        │
│  ┌──────────▼─────────────────┐      │
│  │    Provider Abstraction    │      │
│  │ Tart · OrbStack · Vagrant  │      │
│  │ SSH · Docker · local-linux │      │
│  └──────────┬─────────────────┘      │
│             │                        │
│  ┌──────────▼─────────────────┐      │
│  │        Ansible             │      │
│  └────────────────────────────┘      │
└──────────────┬───────────────────────┘
               │ SSH
               ▼
┌──────────────────────────────────────┐
│         Target Systems               │
│  ┌─────────────────────────────┐     │
│  │ Tart VM (macOS native)      │     │
│  ├─────────────────────────────┤     │
│  │ OrbStack machine (macOS)    │     │
│  ├─────────────────────────────┤     │
│  │ Vagrant VM (cross-platform) │     │
│  ├─────────────────────────────┤     │
│  │ Physical/Cloud Server       │     │
│  │ (AWS/Azure/GCP/DigitalOcean)│     │
│  ├─────────────────────────────┤     │
│  │ This machine (local Linux)  │     │
│  └─────────────────────────────┘     │
└──────────────────────────────────────┘

File Structure:
.
├── Makefile               # Main orchestrator
├── config.mk             # Provider selection
├── providers/
│   ├── tart.mk          # Tart operations (macOS)
│   ├── orbstack.mk      # OrbStack operations (macOS)
│   ├── vagrant.mk       # Vagrant operations
│   ├── ssh.mk           # SSH operations
│   ├── docker.mk        # Docker operations (CI)
│   └── local-linux.mk   # Local Linux loopback operations
└── ansible/
    ├── inventory/
    │   ├── tart.ini       # Dynamic Tart inventory
    │   ├── orbstack.ini   # OrbStack inventory
    │   ├── vagrant.ini    # Dynamic Vagrant inventory
    │   ├── ssh.ini        # SSH hosts inventory
    │   ├── docker.ini     # Docker inventory
    │   └── local-linux.ini # Local loopback inventory
    └── playbooks/      # DSpace installation
```

## Prerequisites

### Control Machine Requirements
- Ansible 2.9+ (can be installed via pip, homebrew, apt, etc.)
- SSH client
- Python 3.x

### Target Host Requirements
- Ubuntu 20.04+ or Debian-based Linux
- SSH access with sudo privileges
- At least 4GB RAM (8GB recommended)
- 20GB+ free disk space
- Network connectivity for package downloads

### Optional (for local development with Tart VM)
- macOS (Intel or Apple Silicon)
- Homebrew (for installing Tart)
- Tart virtualization

### Optional (for local development with OrbStack)
- macOS (Intel or Apple Silicon)
- [OrbStack](https://orbstack.dev) (`brew install orbstack`)

### Optional (for the local-linux loopback provider)
- A Debian/Ubuntu Linux host (this is the deployment target itself)
- Passwordless sudo for the current user
- Best used on a dedicated machine/VM — see the warning in the loopback section below

## Quick Start

### Recommended Workflow

```bash
# 1. Build VM and install complete DSpace stack (backend + frontend + nginx)
make build-vm install-complete

# 2. Access your DSpace installation
#    Frontend: http://dspace-server/
#    Backend:  http://dspace-server/server/api

# 3. When done, clean up the VM
make destroy-vm
```

### Using Tart (macOS Native Virtualization)

```bash
# Default provider is Tart
make configure-developer-machine
make install-dspace-all

# Or install complete stack with frontend
make install-complete

# Access the VM
make ssh

# Clean up when done
make destroy-vm
```

### Using OrbStack (macOS Linux Machines)

[OrbStack](https://orbstack.dev) runs fast, lightweight Linux machines on macOS.
OrbStack manages SSH keys automatically and shares host resources dynamically, so
there is no key-copy or VM-sizing step.

```bash
# Set OrbStack as provider
PROVIDER=orbstack make configure-developer-machine
PROVIDER=orbstack make install-dspace-all

# Or install complete stack with frontend
PROVIDER=orbstack make install-complete

# Access the machine (OrbStack SSH proxy)
PROVIDER=orbstack make ssh        # equivalent to: ssh dspace-server@orb

# Clean up when done
PROVIDER=orbstack make destroy-vm

# Optional: choose a different base image (default: ubuntu:noble)
PROVIDER=orbstack ORBSTACK_IMAGE=ubuntu:jammy make build-vm
```

### Using local-linux (Loopback — Install on This Machine)

The `local-linux` provider installs DSpace **onto the Linux machine you're running
`make` on**, using Ansible's local connection (no VM, no SSH). It is ideal for a
freshly provisioned Ubuntu/Debian server or VM that *is* the deployment target.

```bash
# Install the complete stack directly on this machine
PROVIDER=local-linux make build-vm install-complete

# Or step by step
PROVIDER=local-linux make build-vm           # validates host (Linux + passwordless sudo)
PROVIDER=local-linux make install-dspace-all # backend only
```

> **⚠️ Warning:** This provider targets the local machine. `build-vm` runs
> `update-system.yml`, which may upgrade packages and **reboot the host**. Use a
> dedicated machine/VM, not your daily-driver workstation.
>
> **Requirements:** a Debian/Ubuntu host and **passwordless sudo** for the current
> user. On macOS this provider refuses to run (use `tart` or `orbstack` instead) —
> that's why it's named `local-linux`. `start-vm`/`stop-vm`/`destroy-vm` are no-ops.

### Using Vagrant (Cross-platform)

```bash
# Set Vagrant as provider
PROVIDER=vagrant make configure-developer-machine
PROVIDER=vagrant make install-dspace-all

# Or install complete stack with frontend
PROVIDER=vagrant make install-complete

# Or set as default in config.mk
echo "PROVIDER ?= vagrant" > config.mk
make build-vm install-complete

# Clean up when done
PROVIDER=vagrant make destroy-vm
```

### Using SSH (Physical/Cloud Servers)

```bash
# Connect to existing host
PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host
PROVIDER=ssh SSH_HOST=192.168.1.100 make install-dspace-all

# Or install complete stack with frontend
PROVIDER=ssh SSH_HOST=192.168.1.100 make install-complete

# For cloud instances
PROVIDER=ssh SSH_HOST=ec2-xx-xx-xx-xx.compute.amazonaws.com SSH_USER=ubuntu make configure-host

# Note: destroy-vm doesn't apply to SSH provider (it won't delete your remote server)
```

## Provider Configuration

### Setting Default Provider

Edit `config.mk`:
```makefile
# Change default provider
PROVIDER ?= vagrant  # or tart, orbstack, ssh, docker, local-linux
```

### Provider-Specific Variables

#### Tart Configuration
```bash
# In config.mk or environment
TART_IMAGE=ghcr.io/cirruslabs/ubuntu:latest
VM_NAME=dspace-server
```

#### OrbStack Configuration
```bash
# In config.mk or environment
ORBSTACK_IMAGE=ubuntu:noble   # base distro:version (default: ubuntu:noble)
VM_NAME=dspace-server         # OrbStack machine name
```

#### local-linux Configuration
```bash
# No variables required — the target is the local machine.
# The current user must have passwordless sudo, and the host must be
# a Debian/Ubuntu Linux system.
```

#### Vagrant Configuration
```bash
# In config.mk or environment
VAGRANT_BOX=ubuntu/jammy64
VAGRANT_CPUS=2
VAGRANT_MEMORY=4096
```

#### SSH Configuration
```bash
# Environment variables (required for SSH provider)
SSH_HOST=your-server.example.com
SSH_PORT=22            # optional, defaults to 22
SSH_USER=ubuntu        # optional, defaults to admin
```

## Usage Examples

### VM Management (Tart/Vagrant)
```bash
# Start VM
make start-vm

# Stop VM
make stop-vm

# Check status
make vm-status

# SSH into VM/host
make ssh

# Destroy and recreate
make destroy-vm
make build-vm
```

### Opening DSpace in a Browser
```bash
# Open the frontend (resolves the host from the active provider)
make open-browser

# Open the backend API or the Solr admin UI
make open-api
make open-solr

# Same host, a different path; or open an explicit URL
make open-browser BROWSER_PATH=server/api
make open-browser URL=http://1.2.3.4:8983/solr
```
These work across all providers (the host comes from the active provider's
IP — VM IP, SSH host, or 127.0.0.1 for local-linux) and use `open` (macOS),
`xdg-open` (Linux), or `wslview` (WSL).

### Changing the Access URL

DSpace must be reached at the URL it's configured for — the browser uses that
URL for API calls, so a mismatch (e.g. opening `https://<ip>/` when it's
configured for `http://dspace-server.localnet/`) breaks the UI with a
"Service Unavailable" page. To re-point a running install at a different URL:

```bash
# Access by IP over HTTP (no /etc/hosts entry needed)
make set-access-url URL=http://192.168.64.11

# Access by hostname / real domain
make set-access-url URL=https://dspace.example.org
```

This rewrites the backend (`dspace.ui.url`, `dspace.server.url`, CORS) and the
frontend (`rest` host/port/ssl), then restarts Tomcat and the frontend. It's
idempotent.

> **HTTPS note:** if you use `https://`, the SSR server (Node) must trust the
> REST API's certificate. Use a properly-issued cert (e.g. Let's Encrypt via the
> `certbot` role) or add your dev CA to the system trust store on the VM — do
> **not** disable TLS verification (`NODE_TLS_REJECT_UNAUTHORIZED=0`), as that
> exposes the SSR↔API traffic to MITM. For local dev, the `http://<host>` form
> avoids this entirely.

### DSpace Installation Options
```bash
# Install default DSpace version
make install-dspace

# Install specific version
make dspace-version VERSION=9.1

# Install from GitHub branch
make dspace-github BRANCH=main

# Rebuild existing installation (skip download)
make dspace-rebuild

# (Optional) Install handles server after DSpace installation
make install-handles-server
```

### System Maintenance
```bash
# Update Ubuntu packages
make update-apt

# Completely reset environment
make destroy-vm
make build-vm
```

## Available Make Targets

All targets work with any provider (Tart, OrbStack, Vagrant, SSH, Docker, or local-linux). Set provider via `PROVIDER` environment variable or in `config.mk`.

| Target | Description |
|--------|-------------|
| `help` | Display all available targets |
| `info` | Show current provider and configuration |
| **Setup & Configuration** | |
| `configure-developer-machine` | Install dependencies and initialize VM/host |
| `build-vm` | Create VM or validate SSH host (provider-specific) |
| `configure-host` | Alias for build-vm when using SSH provider |
| `ssh-copy-id` | Copy SSH keys to VM/host |
| `set-access-url` | Point backend + frontend at a public URL (URL=http://host[:port]) |
| **VM/Host Management** | |
| `start-vm` | Start VM (no-op for SSH/local-linux providers) |
| `stop-vm` | Stop VM (no-op for SSH/local-linux providers) |
| `destroy-vm` | Delete VM (no-op for SSH/local-linux providers) |
| `vm-status` | Check VM/host status |
| `ssh` | SSH into VM/host |
| `open-browser` | Open the DSpace frontend in your default browser |
| `open-api` | Open the DSpace backend (`/server/`, REST/HAL browser) in your browser |
| `open-solr` | Open the Solr admin UI (`:8983/solr`) in your browser |
| **DSpace Installation** | |
| `install-prerequisites` | Install Java, PostgreSQL, Solr, Tomcat |
| `install-dspace` | Complete DSpace backend installation |
| `install-handles-server` | (Optional) Install handles server for DSpace |
| `install-dspace-all` | Install prerequisites + DSpace backend |
| `install-complete` | Install complete stack (backend + frontend + nginx) |
| `install-frontend` | Install DSpace Angular frontend |
| `dspace-download` | Download DSpace source only |
| `dspace-build` | Build with Maven and Ant only |
| `dspace-install-only` | Install without download/build |
| `dspace-rebuild` | Rebuild existing installation |
| `dspace-version` | Install specific version (VERSION=x.x) |
| `dspace-github` | Install from GitHub branch (BRANCH=xxx) |
| **Maintenance & Utilities** | |
| `update-apt` | Update Ubuntu packages via Ansible |
| `check-services` | Check status of all DSpace services |
| `tail-logs` | Follow backend logs live (Ctrl+C; `LOG_FILE=`/`LINES=` overridable) |
| `frontend-logs` | Follow frontend (PM2) logs live |
| `frontend-restart` | Restart the frontend (PM2 process) |
| `frontend-status` | Show frontend (PM2) status |
| `clean-logs` | Clean DSpace logs |
| `backup-db` | Backup DSpace database |
| `migrate-plan` | Preview migrating a legacy install on the host (`EXISTING=/old/dspace`) |
| `migrate-from` | Migrate a legacy install into this one (resumable; `EXISTING=`, `START_AT=`, `WITH_STATS=1`) |
| `clean` | Remove Emacs backup files (*~, #*#, .#*) |

## Ansible Playbooks (for any SSH target)

| Playbook | Description | Usage |
|----------|-------------|-------|
| `update-system.yml` | Update apt packages and reboot if needed | `ansible-playbook -i inventory.ini update-system.yml` |
| `install-prerequisites.yml` | Install Java, PostgreSQL, Solr, Tomcat | `ansible-playbook -i inventory.ini install-prerequisites.yml` |
| `install-dspace.yml` | Complete DSpace installation | `ansible-playbook -i inventory.ini install-dspace.yml` |
| `dspace-download.yml` | Download DSpace source code | `ansible-playbook -i inventory.ini dspace-download.yml` |
| `dspace-build.yml` | Build DSpace with Maven | `ansible-playbook -i inventory.ini dspace-build.yml` |
| `dspace-install-only.yml` | Install pre-built DSpace | `ansible-playbook -i inventory.ini dspace-install-only.yml` |
| `set-access-url.yml` | Re-point a running install at a public URL | `ansible-playbook -i inventory.ini set-access-url.yml -e access_url=http://host` |
| `migrate-local.yml` | Migrate a same-host legacy install into this one | `ansible-playbook -i inventory.ini migrate-local.yml -e existing_dspace_dir=/old/dspace` |

## Configuration

### Ansible Configuration
- **Main config**: `ansible/ansible.cfg` - Ansible settings (host checking, retry files, etc.)
- **Inventory**: `ansible/inventory.ini` - Define your target hosts here
- **Variables**: `ansible/group_vars/all.yml` - Customize DSpace version, paths, etc.

### Target Host Requirements
- Ubuntu 20.04+ or Debian-based Linux
- SSH access with sudo privileges
- 4GB+ RAM (8GB recommended)
- 20GB+ disk space
- Internet connectivity for packages

### DSpace Installation Details
- **Base directory**: `/opt/dspace`
- **Database**: PostgreSQL 16
- **Search engine**: Apache Solr 9.10.1
- **Application server**: Apache Tomcat 10.1.33
- **Java**: OpenJDK 17
- **Handles server**: Optional, runs as systemd service (install with `make install-handles-server`)

### Firewall (UFW)

`install-prerequisites` configures the host firewall via the `ufw` role. SSH (22),
HTTP (80), HTTPS (443) and the Handle server ports (2641) are always allowed;
development ports (Tomcat 8080/8000, frontend 4000) and debug ports (Solr 8983,
PostgreSQL 5432) open depending on the mode. Controlled in `group_vars/all.yml`:

```yaml
firewall_enabled: true            # set false to skip firewall configuration
firewall_mode: "development"      # production | development | all
ufw_default_incoming: "deny"
ufw_default_outgoing: "allow"
ufw_default_routed: "deny"
```

## Project Structure
```
.
├── Makefile                       # Main orchestrator (provider-agnostic)
├── config.mk                      # Provider selection and configuration
├── providers/                     # Provider implementations
│   ├── tart.mk                  # Tart VM operations (macOS)
│   ├── orbstack.mk              # OrbStack machine operations (macOS)
│   ├── vagrant.mk               # Vagrant VM operations
│   ├── ssh.mk                   # SSH host operations
│   ├── docker.mk                # Docker container operations (CI)
│   └── local-linux.mk           # Local Linux loopback operations
├── CLAUDE.md                      # Development notes
├── LICENSE                        # MIT License
├── README.md                      # This file
└── ansible/
    ├── ansible.cfg                # Ansible configuration
    ├── inventory/                 # Provider-specific inventories
    │   ├── tart.ini              # Dynamic Tart inventory
    │   ├── orbstack.ini          # OrbStack inventory
    │   ├── vagrant.ini           # Dynamic Vagrant inventory
    │   ├── ssh.ini               # SSH hosts inventory
    │   ├── docker.ini            # Docker inventory
    │   └── local-linux.ini       # Local loopback inventory
    ├── group_vars/
    │   └── all.yml               # Global variables
    ├── callback_plugins/
    │   └── resume_hint.py         # Friendly "resume from failed task" hint
    ├── roles/                     # Ansible roles
    │   ├── certbot/               # Let's Encrypt SSL
    │   ├── dspace/                # DSpace core config (local.cfg)
    │   ├── dspace-base/           # DSpace base setup
    │   ├── dspace-build/          # Maven/Ant build
    │   ├── dspace-download/       # Source download
    │   ├── dspace-frontend/       # Angular UI + PM2
    │   ├── dspace-install/        # Install + admin account
    │   ├── firefox/               # Firefox (testing)
    │   ├── java/                  # Java 17
    │   ├── nginx/                 # Reverse proxy
    │   ├── postgresql/            # PostgreSQL 16
    │   ├── solr/                  # Apache Solr
    │   ├── swap/                  # Swap configuration
    │   ├── tomcat/                # Apache Tomcat
    │   └── ufw/                   # Host firewall (UFW)
    ├── install-prerequisites.yml  # Install stack (incl. ufw firewall)
    ├── install-dspace.yml         # Full DSpace backend
    ├── install-frontend.yml       # Full Angular frontend
    ├── install-handles-server.yml # Optional handle server
    ├── set-access-url.yml         # Re-point install at a public URL
    ├── update-system.yml          # System updates
    └── ...                        # granular dspace-*/frontend-* playbooks
```

## Troubleshooting

### Provider-Specific Issues

#### Tart (macOS)
```bash
# Check if Tart is installed
brew list tart || brew install cirruslabs/cli/tart

# Check VM status
tart list
make vm-status

# Recreate VM if issues persist
make destroy-vm
make build-vm
```

#### Vagrant
```bash
# Check Vagrant status
vagrant status

# Check VirtualBox
VBoxManage list vms

# Debug Vagrant issues
PROVIDER=vagrant make vm-status
vagrant up --debug

# Reset Vagrant VM
PROVIDER=vagrant make destroy-vm
PROVIDER=vagrant make build-vm
```

#### SSH Provider
```bash
# Test connection
PROVIDER=ssh SSH_HOST=your-host make vm-status

# Check sudo privileges
ssh user@host "sudo -n true" || echo "Sudo requires password"

# Verify host compatibility
ssh user@host "lsb_release -a"

# Debug with verbose output
ANSIBLE_VERBOSE=-vvv PROVIDER=ssh SSH_HOST=your-host make install-dspace
```

#### OrbStack (macOS)
```bash
# Check if OrbStack is installed
command -v orbctl || brew install orbstack

# List machines and check status
orbctl list
PROVIDER=orbstack make vm-status

# Connect manually (OrbStack SSH proxy)
ssh dspace-server@orb

# Recreate the machine if issues persist
PROVIDER=orbstack make destroy-vm
PROVIDER=orbstack make build-vm
```

#### local-linux (Loopback)
```bash
# Must be run ON the Debian/Ubuntu target host (refuses on macOS)
PROVIDER=local-linux make vm-status

# Verify passwordless sudo (required)
sudo -n true && echo "OK" || echo "Add: '<user> ALL=(ALL) NOPASSWD:ALL' to /etc/sudoers.d/dspace-installer"

# Debug with verbose output
ANSIBLE_VERBOSE=-vvv PROVIDER=local-linux make install-dspace
```

### DSpace Installation Issues

#### Build Failures
```bash
# Check Java version (should be 17)
java -version

# Check Maven memory settings
echo $MAVEN_OPTS

# Increase Maven memory
export MAVEN_OPTS="-Xmx2048m"

# Retry build
ansible-playbook -i ansible/inventory.ini ansible/dspace-build.yml
```

#### Database Connection Issues
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check database exists
sudo -u postgres psql -l

# Check DSpace database user
sudo -u postgres psql -c "\du"
```

### Resuming After a Failed Task

If an Ansible run stops on a failed task, the installer prints a friendly hint
right after the play recap: the exact task that failed and a ready-to-paste
command to resume from that point using `--start-at-task`, e.g.:

```bash
# From the project's ansible/ directory
ansible-playbook -v -i inventory/orbstack.ini install-prerequisites.yml \
    --start-at-task="Download Solr"
```

This is handled by the `resume_hint` callback plugin (`ansible/callback_plugins/`).

> **Note:** Resuming from a task only works if that task doesn't depend on
> something an earlier task set up (a registered variable, a gathered fact, a
> `set_fact`, etc.). If resuming gives "undefined variable" errors, just re-run
> the whole step — Ansible is idempotent, so the parts that already succeeded
> are skipped. The hint shows both commands.

### Complete Reset

#### For Tart VM
```bash
make destroy-vm
make configure-developer-machine
```

#### For Other Hosts
```bash
# Remove DSpace installation
sudo rm -rf /opt/dspace
sudo rm -rf /opt/dspace-source

# Drop database
sudo -u postgres psql -c "DROP DATABASE dspace;"
sudo -u postgres psql -c "DROP USER dspace;"

# Rerun installation
ansible-playbook -i ansible/inventory.ini ansible/install-dspace.yml
```

## Advanced Usage

### Custom DSpace Configuration
Edit `ansible/group_vars/all.yml` to customize:
- DSpace version
- Database settings
- Tomcat configuration
- Java options

### Running Individual Playbooks
```bash
cd ansible
ansible-playbook -i inventory.ini install-prerequisites.yml
ansible-playbook -i inventory.ini dspace-build.yml
```

### VM Resource Adjustment
Modify VM settings in the Makefile:
- RAM allocation
- CPU cores
- Disk size

## Documentation

Additional guides are available in the `docs/` directory:

- [Data Migration Guide](docs/data-migration.md) - Move an existing DSpace installation (database, assetstore, statistics, config) onto a fresh server built with this repo
- [Self-Submission Guide (English)](docs/self-submission-guide.rst) - Comprehensive guide for configuring and using self-submission in DSpace 9
- [Self-Submission Guide (Polski)](docs/self-submission-guide-pl.rst) - Przewodnik konfiguracji i używania samodzielnego przesyłania w DSpace 9

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the CLAUDE.md file for detailed framework information

## Acknowledgments

- [DSpace](https://duraspace.org/dspace/) community
- [Tart](https://github.com/cirruslabs/tart) for macOS virtualization
- [OrbStack](https://orbstack.dev) for fast Linux machines on macOS
- [Ansible](https://www.ansible.com/) for automation
