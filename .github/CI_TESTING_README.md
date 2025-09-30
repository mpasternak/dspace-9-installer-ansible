# GitHub Actions CI Testing with Vagrant

## ⚠️ IMPORTANT: FOR CI TESTING PURPOSES ONLY ⚠️

This directory contains GitHub Actions workflows that use **Vagrant** to create real Ubuntu 24.04 VMs for testing the DSpace 9 installation process. This ensures the installation works exactly as it would on developer machines.

## Overview

The CI pipeline:
1. **Creates a real VM** using Vagrant (not a container)
2. **Provisions Ubuntu 24.04 LTS** in the VM
3. **Runs the complete installation** using `make update-apt install-complete`
4. **Validates** that everything installed correctly
5. **Collects logs** if anything fails

## Key Differences from Container-based CI

| Aspect | Vagrant VM | Container |
|--------|------------|-----------|
| **Environment** | Full Ubuntu 24.04 VM | Containerized Ubuntu |
| **Systemd** | Full systemd support | Limited systemd |
| **Services** | Run as real services | May need workarounds |
| **Resource Usage** | Higher (full VM) | Lower (shared kernel) |
| **GitHub Actions Cost** | Uses macOS runners (10x minutes) | Uses Linux runners (1x minutes) |
| **Fidelity** | Exactly like dev environment | May differ from real VMs |

## Files

### `.github/workflows/test-vagrant-installation.yml`
Main GitHub Actions workflow that:
- Runs on macOS runners (required for VirtualBox)
- Creates a Vagrant VM with Ubuntu 24.04
- Installs DSpace using your existing Ansible playbooks
- Validates the installation

### `.github/Vagrantfile.ci`
CI-specific Vagrant configuration:
- Optimized for automated testing
- 8GB RAM, 4 CPUs for performance
- Includes all necessary port forwarding
- Sets up admin user for Ansible

## Running the Tests

### Automatic Triggers

Tests run automatically when:
- You **push** to the `main` branch
- You create a **pull request** to `main`

### Manual Trigger

1. Go to the [Actions tab](../../../actions) in your repository
2. Select "Test DSpace Installation (Vagrant)"
3. Click "Run workflow"
4. Choose test type:
   - `complete` - Full installation (backend + frontend)
   - `backend` - Backend with prerequisites only
   - `prerequisites` - Just system prerequisites
5. Optionally enable verbose Ansible output
6. Click "Run workflow"

## Test Types Explained

### Complete Installation
```bash
make update-apt
make install-complete
```
Tests the full stack including:
- PostgreSQL, Java, Tomcat, Solr
- DSpace backend
- DSpace Angular frontend
- Nginx proxy configuration

### Backend Only
```bash
make update-apt
make install-prerequisites
make install-dspace
```
Tests just the backend:
- All prerequisites
- DSpace backend application
- No frontend components

### Prerequisites Only
```bash
make update-apt
make install-prerequisites
```
Tests just the foundation:
- Java 17
- PostgreSQL 16
- Tomcat 10
- Solr 9.6.1

## Understanding Test Results

### Success ✅
- All installation steps completed
- Services are running
- Validation checks passed

### Failure ❌
- Check the workflow logs
- Download artifacts for detailed logs
- Common issues:
  - Network timeouts during package downloads
  - Build failures due to resource constraints
  - Service start failures

## Debugging Failed Tests

### 1. Check Workflow Logs
Click on the failed job to see detailed output from each step.

### 2. Download Artifacts
Failed runs upload logs as artifacts:
- DSpace application logs
- System service logs
- Ansible output

### 3. Run Locally
Reproduce the issue locally:

```bash
# On macOS with Vagrant installed
git clone <your-repo>
cd dspace-9-installer

# Use the CI Vagrantfile
cp .github/Vagrantfile.ci Vagrantfile

# Start VM
vagrant up

# Run installation
make configure-developer-machine
make update-apt
make install-complete

# Check status
vagrant ssh
sudo systemctl status tomcat solr postgresql
```

## GitHub Actions Costs

**Important:** This workflow uses **macOS runners** which consume GitHub Actions minutes at 10x the rate of Linux runners:

- Free accounts: 2,000 minutes/month = 200 macOS minutes
- Pro accounts: 3,000 minutes/month = 300 macOS minutes

Each full test run takes approximately 30-45 macOS minutes (300-450 standard minutes).

### Cost Optimization Tips

1. **Use manual triggers** instead of running on every push
2. **Test locally first** before pushing
3. **Cancel redundant runs** if you push multiple times
4. **Use prerequisites/backend tests** when full stack isn't needed

## Security Notes

⚠️ **This setup is FOR TESTING ONLY** and includes:
- Default passwords (`admin:admin`)
- NOPASSWD sudo access
- Permissive SSH configuration

**NEVER** use these settings in production!

## Local Testing Without GitHub Actions

You can test locally without using GitHub Actions minutes:

### Prerequisites
- macOS or Linux with virtualization support
- Vagrant installed
- VirtualBox or VMware installed
- 8GB+ free RAM
- 20GB+ free disk space

### Steps

```bash
# Clone repository
git clone <your-repo>
cd dspace-9-installer

# Copy CI Vagrantfile (optional)
cp .github/Vagrantfile.ci Vagrantfile

# Start Vagrant VM
vagrant up

# Configure your machine and build VM
make configure-developer-machine

# Install DSpace
make update-apt
make install-complete

# Validate
vagrant ssh -c "sudo systemctl status postgresql tomcat solr"
```

## Troubleshooting

### VirtualBox Issues on macOS

If VirtualBox fails to start:
```bash
# Check System Preferences > Security & Privacy
# Allow Oracle VirtualBox kernel extension

# Restart VirtualBox kernel modules
sudo kextload -b org.virtualbox.kext.VBoxDrv
```

### Vagrant Connection Issues

```bash
# Rebuild SSH config
vagrant ssh-config > ~/.ssh/config.d/vagrant

# Force reprovisioning
vagrant provision

# Complete rebuild
vagrant destroy -f
vagrant up
```

### Ansible Connection Issues

```bash
# Test Ansible connection
cd ansible
ansible -i inventory/vagrant.ini all -m ping

# Run with verbose output
ANSIBLE_VERBOSE=-vvv make install-prerequisites
```

## Maintenance

### Updating Ubuntu Version
Edit `.github/Vagrantfile.ci`:
```ruby
config.vm.box = "bento/ubuntu-24.10"  # Change version
```

### Changing Resources
Edit `.github/Vagrantfile.ci`:
```ruby
vb.memory = "16384"  # Increase RAM to 16GB
vb.cpus = 8          # Use 8 CPUs
```

### Adding Test Scenarios
Edit `.github/workflows/test-vagrant-installation.yml` and add new options to the `test_type` input.

## Best Practices

1. **Test locally first** to save GitHub Actions minutes
2. **Use caching** where possible (though Vagrant limits this)
3. **Monitor resource usage** - full builds need significant resources
4. **Keep logs concise** but informative
5. **Document failures** with issues

## Related Documentation

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [VirtualBox Documentation](https://www.virtualbox.org/manual/)
- [Main Project README](../README.md)

---

**Remember**: This CI setup creates **real VMs** for testing, ensuring your installation process works exactly as it would for developers, but at the cost of higher resource usage and GitHub Actions minutes.