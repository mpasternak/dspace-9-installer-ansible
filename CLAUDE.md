# DSpace 9 Development Framework

## Overview
This framework provides automated setup and management for DSpace 9 frontend and backend development servers using Tart virtualization on macOS.

## Architecture
- **Host**: macOS development machine
- **Virtualization**: Tart (macOS native virtualization)
- **Guest OS**: Ubuntu Linux VM
- **Target**: DSpace 9 (frontend and backend servers)
- **Automation**: Ansible for configuration management

## Prerequisites
- macOS with Tart installed
- Ansible installed on host machine
- Ubuntu VM image for Tart

## Components

### Configuration Files
- `ansible.cfg` - Ansible configuration
- `inventory.ini` - Target hosts inventory
- `update-system.yml` - System update playbook with automatic reboot support
- `Makefile` - Build and deployment automation

### Key Features
1. **Automated System Updates**: The Ansible playbook updates the Ubuntu system and automatically reboots if required
2. **VM Management**: Uses Tart for lightweight macOS-native virtualization
3. **DSpace 9 Support**: Configured for both frontend and backend development

## Usage

### System Updates
The `update-system.yml` playbook:
- Updates apt cache
- Performs dist-upgrade
- Removes unnecessary packages
- Automatically reboots if system updates require it

### Development Workflow
1. Start Tart VM with Ubuntu
2. Run Ansible playbooks for configuration
3. Deploy DSpace 9 frontend and backend
4. Use Make targets for common tasks

## Notes
- The framework checks `/var/run/reboot-required` to determine if a reboot is needed after updates
- Reboot is handled gracefully with configurable timeouts and connection recovery
- Suitable for local development environments on macOS machines
- To verify anything on the server for development, use: `ssh admin@$(tart ip dspace-server)`