# DSpace 9 Ansible Installer

> Ansible-based automation framework for installing DSpace 9 on Linux systems via SSH - from local VMs to cloud providers

## Overview

This project provides a comprehensive Ansible automation framework for deploying DSpace 9 to any Linux system accessible via SSH. While it includes convenient integration with Tart VMs for macOS users who want local development environments, it's designed to work with any SSH-accessible Linux host including cloud providers (AWS, Azure, GCP), bare metal servers, Docker containers, or other virtualization platforms.

## Features

- **Target Agnostic**: Deploy to any SSH-accessible Linux system (Ubuntu/Debian-based)
- **Ansible Automation**: Idempotent, repeatable deployments using Ansible playbooks
- **Complete DSpace Stack**: Automated installation of all prerequisites (Java, PostgreSQL, Solr, Tomcat)
- **Version Flexibility**: Deploy specific DSpace versions or build from GitHub branches
- **Multiple Deployment Targets**: Local VMs, cloud instances, containers, or bare metal
- **macOS Friendly**: Includes Makefile automation and optional Tart VM setup for local development

## Architecture

```
┌─────────────────────────────────┐
│     Control Machine             │
│   (macOS/Linux/Windows)         │
│  ┌───────────────────────┐      │
│  │      Ansible          │      │
│  └───────────┬───────────┘      │
└──────────────┼──────────────────┘
               │ SSH
               ▼
┌─────────────────────────────────┐
│     Target Systems              │
│                                 │
│  ┌───────────────────────┐      │
│  │   Local VM (Tart)     │      │
│  └───────────────────────┘      │
│                                 │
│  ┌───────────────────────┐      │
│  │   Cloud Instance      │      │
│  │  (AWS/Azure/GCP)      │      │
│  └───────────────────────┘      │
│                                 │
│  ┌───────────────────────┐      │
│  │   Bare Metal Server   │      │
│  └───────────────────────┘      │
│                                 │
└─────────────────────────────────┘

Each target runs:
- Ubuntu/Debian Linux
- DSpace 9 (Frontend + Backend)
- PostgreSQL, Solr, Tomcat
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

### Option 1: Deploy to Existing Linux Host

#### 1. Clone the repository
```bash
git clone https://github.com/yourusername/dspace-9-installer.git
cd dspace-9-installer
```

#### 2. Configure your target host
```bash
# Edit inventory file to add your host
vim ansible/inventory.ini

# Add your host details:
[dspace_hosts]
your-server ansible_host=192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

#### 3. Deploy DSpace
```bash
# Test connection
ansible -i ansible/inventory.ini all -m ping

# Install DSpace and prerequisites
cd ansible
ansible-playbook -i inventory.ini install-prerequisites.yml
ansible-playbook -i inventory.ini install-dspace.yml
```

### Option 2: Local Development with Tart VM (macOS)

#### 1. Clone and setup
```bash
git clone https://github.com/yourusername/dspace-9-installer.git
cd dspace-9-installer

# Install Tart and create VM (macOS only)
make configure-developer-machine
```

#### 2. Deploy to local VM
```bash
# Install prerequisites and DSpace in one command
make install-dspace-all

# Access the VM
make ssh
```

## Usage Examples

### Deploying to Different Targets

#### AWS EC2 Instance
```bash
# Add to inventory.ini
[dspace_hosts]
aws-dspace ansible_host=ec2-xx-xx-xx-xx.compute.amazonaws.com ansible_user=ubuntu

# Deploy
ansible-playbook -i ansible/inventory.ini ansible/install-dspace.yml
```

#### DigitalOcean Droplet
```bash
# Add to inventory.ini
[dspace_hosts]
do-dspace ansible_host=165.232.xx.xx ansible_user=root

# Deploy
ansible-playbook -i ansible/inventory.ini ansible/install-dspace.yml
```

### Local Tart VM Management (macOS)
```bash
# Start the VM
make start-vm

# Stop the VM
make stop-vm

# Check VM and service status
make vm-status

# SSH into the VM
make ssh
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
```

### System Maintenance
```bash
# Update Ubuntu packages
make update-apt

# Completely reset environment
make destroy-vm
make build-vm
```

## Available Make Targets (for Tart VM workflow)

Note: These Make targets are specifically for the local Tart VM development workflow on macOS. For other SSH targets, use the Ansible playbooks directly.

| Target | Description |
|--------|-------------|
| `help` | Display all available targets |
| **Setup & Configuration** | |
| `configure-developer-machine` | Install Homebrew, Tart, and create VM |
| `build-vm` | Build and configure Tart VM |
| `ssh-copy-id` | Copy SSH keys to Tart VM |
| **VM Management** | |
| `start-vm` | Start the Tart VM |
| `stop-vm` | Stop the Tart VM |
| `destroy-vm` | Remove Tart VM for clean restart |
| `vm-status` | Check VM and services status |
| `ssh` | SSH into the Tart VM |
| **DSpace Installation** | |
| `install-prerequisites` | Install Java, PostgreSQL, Solr, Tomcat |
| `install-dspace` | Complete DSpace installation |
| `install-dspace-all` | Install prerequisites + DSpace |
| `dspace-download` | Download DSpace source only |
| `dspace-build` | Build with Maven and Ant only |
| `dspace-install-only` | Install without download/build |
| `dspace-rebuild` | Rebuild existing installation |
| `dspace-version` | Install specific version (VERSION=x.x) |
| `dspace-github` | Install from GitHub branch (BRANCH=xxx) |
| **Maintenance** | |
| `update-apt` | Update Ubuntu packages via Ansible |

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
- **Database**: PostgreSQL 12+
- **Search engine**: Apache Solr 8.11
- **Application server**: Apache Tomcat 9
- **Java**: OpenJDK 11

## Project Structure
```
.
├── Makefile                       # Automation for Tart VM workflow
├── CLAUDE.md                      # Development notes
├── LICENSE                        # MIT License
├── README.md                      # This file
└── ansible/
    ├── ansible.cfg                # Ansible configuration
    ├── inventory.ini              # SSH target hosts
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

### General SSH Target Issues

#### Connection Problems
```bash
# Test SSH connectivity
ssh user@your-host

# Test Ansible connectivity
ansible -i ansible/inventory.ini all -m ping

# Debug connection issues
ansible -i ansible/inventory.ini all -m ping -vvv
```

#### Permission Issues
```bash
# Ensure sudo works without password prompt
ssh user@host
sudo -l

# Or configure ansible to prompt for sudo password
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
```

### Tart VM Specific Issues (macOS)

#### VM Won't Start
```bash
# Check if VM exists
tart list

# Check VM status
tart status dspace-vm

# Recreate VM
make destroy-vm
make build-vm
```

#### SSH to VM Fails
```bash
# Get VM IP
tart ip dspace-vm

# Copy SSH keys manually
ssh-copy-id dspace@$(tart ip dspace-vm)

# Or use Make target
make ssh-copy-id
```

### DSpace Installation Issues

#### Build Failures
```bash
# Check Java version (should be 11)
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
