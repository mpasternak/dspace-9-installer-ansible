# DSpace 9 Installer

> Provider-agnostic automation framework for installing DSpace 9 with support for Tart VMs, Vagrant, and direct SSH hosts

## Overview

This project provides a flexible, provider-agnostic framework for deploying DSpace 9 to various targets. Whether you're using local VMs (Tart on macOS or Vagrant cross-platform) or deploying to physical servers and cloud instances via SSH, this framework handles it all with a consistent interface.

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

- **Multiple Provider Support**: Choose between Tart (macOS), Vagrant (cross-platform), or direct SSH connections
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
│  │  ┌──────┐ ┌────────┐ ┌────┐│      │
│  │  │ Tart │ │Vagrant │ │SSH ││      │
│  │  └──────┘ └────────┘ └────┘│      │
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
│  │ Vagrant VM (cross-platform) │     │
│  ├─────────────────────────────┤     │
│  │ Physical/Cloud Server       │     │
│  │ (AWS/Azure/GCP/DigitalOcean)│     │
│  └─────────────────────────────┘     │
└──────────────────────────────────────┘

File Structure:
.
├── Makefile              # Main orchestrator
├── config.mk            # Provider selection
├── providers/
│   ├── tart.mk         # Tart operations
│   ├── vagrant.mk      # Vagrant operations
│   └── ssh.mk          # SSH operations
└── ansible/
    ├── inventory/
    │   ├── tart.ini    # Dynamic Tart inventory
    │   ├── vagrant.ini # Dynamic Vagrant inventory
    │   └── ssh.ini     # SSH hosts inventory
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
PROVIDER ?= vagrant  # or tart, ssh
```

### Provider-Specific Variables

#### Tart Configuration
```bash
# In config.mk or environment
TART_IMAGE=ghcr.io/cirruslabs/ubuntu:latest
VM_NAME=dspace-server
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

All targets work with any provider (Tart, Vagrant, or SSH). Set provider via `PROVIDER` environment variable or in `config.mk`.

| Target | Description |
|--------|-------------|
| `help` | Display all available targets |
| `info` | Show current provider and configuration |
| **Setup & Configuration** | |
| `configure-developer-machine` | Install dependencies and initialize VM/host |
| `build-vm` | Create VM or validate SSH host (provider-specific) |
| `configure-host` | Alias for build-vm when using SSH provider |
| `ssh-copy-id` | Copy SSH keys to VM/host |
| **VM/Host Management** | |
| `start-vm` | Start VM (no-op for SSH provider) |
| `stop-vm` | Stop VM (no-op for SSH provider) |
| `destroy-vm` | Delete VM (no-op for SSH provider) |
| `vm-status` | Check VM/host status |
| `ssh` | SSH into VM/host |
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
| `tail-logs` | Tail DSpace logs |
| `clean-logs` | Clean DSpace logs |
| `backup-db` | Backup DSpace database |
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
- **Search engine**: Apache Solr 9.9.0
- **Application server**: Apache Tomcat 10.1.33
- **Java**: OpenJDK 17
- **Handles server**: Optional, runs as systemd service (install with `make install-handles-server`)

## Project Structure
```
.
├── Makefile                       # Main orchestrator (provider-agnostic)
├── config.mk                      # Provider selection and configuration
├── providers/                     # Provider implementations
│   ├── tart.mk                  # Tart VM operations (macOS)
│   ├── vagrant.mk               # Vagrant VM operations
│   └── ssh.mk                   # SSH host operations
├── CLAUDE.md                      # Development notes
├── LICENSE                        # MIT License
├── README.md                      # This file
└── ansible/
    ├── ansible.cfg                # Ansible configuration
    ├── inventory/                 # Provider-specific inventories
    │   ├── tart.ini              # Dynamic Tart inventory
    │   ├── vagrant.ini           # Dynamic Vagrant inventory
    │   └── ssh.ini               # SSH hosts inventory
    ├── group_vars/
    │   └── all.yml               # Global variables
    ├── roles/                     # Ansible roles
    │   ├── dspace-build/
    │   ├── dspace-download/
    │   ├── dspace-install/
    │   ├── java/
    │   ├── postgresql/
    │   ├── solr/
    │   └── tomcat/
    ├── install-prerequisites.yml  # Install stack playbook
    ├── install-dspace.yml         # Full DSpace playbook
    ├── dspace-download.yml        # Download only
    ├── dspace-build.yml          # Build only
    ├── dspace-install-only.yml   # Install only
    └── update-system.yml         # System updates
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
- [Ansible](https://www.ansible.com/) for automation
