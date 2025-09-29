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
│  ┌───────────────────────┐      │
│  │   Docker Container    │      │
│  └───────────────────────┘      │
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

#### Docker Container
```bash
# Start container with SSH
docker run -d -p 2222:22 --name dspace-target ubuntu-ssh-enabled

# Add to inventory.ini
[dspace_hosts]
docker-dspace ansible_host=localhost ansible_port=2222 ansible_user=root

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

## Available Make Targets

| Target | Description |
|--------|-------------|
| `help` | Display all available targets |
| **Setup & Configuration** | |
| `configure-developer-machine` | Complete setup from scratch |
| `build-vm` | Build and configure VM |
| `ssh-copy-id` | Copy SSH keys to VM |
| **VM Management** | |
| `start-vm` | Start the DSpace VM |
| `stop-vm` | Stop the DSpace VM |
| `destroy-vm` | Remove VM for clean restart |
| `vm-status` | Check VM and services status |
| `ssh` | SSH into the VM |
| **DSpace Installation** | |
| `install-prerequisites` | Install Java, PostgreSQL, Solr, Tomcat |
| `install-dspace` | Complete DSpace installation |
| `install-dspace-all` | Install prerequisites + DSpace |
| `dspace-download` | Download DSpace source only |
| `dspace-build` | Build with Maven and Ant only |
| `dspace-install-only` | Install without download/build |
| `dspace-rebuild` | Rebuild existing installation |
| `dspace-version` | Install specific version |
| `dspace-github` | Install from GitHub branch |
| **Maintenance** | |
| `update-apt` | Update Ubuntu packages |

## Configuration

### Ansible Configuration
- Main config: `ansible/ansible.cfg`
- Inventory: `ansible/inventory.ini`
- Variables: `ansible/group_vars/`

### VM Configuration
The VM is configured with:
- Ubuntu Linux (latest LTS)
- 4GB RAM (configurable)
- 20GB disk
- Network access to host

### DSpace Configuration
- Installation directory: `/opt/dspace`
- Database: PostgreSQL
- Search: Apache Solr
- Application server: Apache Tomcat

## Project Structure
```
.
├── Makefile                    # Main automation interface
├── ansible/
│   ├── ansible.cfg            # Ansible configuration
│   ├── inventory.ini          # VM inventory
│   ├── install-dspace.yml     # DSpace installation playbook
│   ├── install-prerequisites.yml # Prerequisites playbook
│   ├── update-system.yml      # System update playbook
│   ├── group_vars/            # Ansible variables
│   └── roles/                 # Ansible roles
└── CLAUDE.md                  # Development framework documentation
```

## Troubleshooting

### VM Won't Start
```bash
# Check Tart status
tart list

# Restart from scratch
make destroy-vm
make build-vm
```

### SSH Connection Issues
```bash
# Copy SSH keys again
make ssh-copy-id

# Check VM network
make vm-status
```

### DSpace Build Failures
```bash
# Check Java and Maven versions
make ssh
java -version
mvn -version

# Rebuild DSpace
make dspace-rebuild
```

### Reset Everything
```bash
# Complete cleanup and rebuild
make destroy-vm
make configure-developer-machine
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
