# Migration Guide: Provider Abstraction

This guide helps you migrate from the previous Tart-only setup to the new provider-agnostic architecture.

## What Changed

The DSpace 9 Installer now supports multiple virtualization providers:
- **Tart** (macOS native virtualization) - default
- **Vagrant** (cross-platform with VirtualBox/VMware)
- **SSH** (direct connection to physical/cloud servers)

## Migration Steps

### For Existing Tart Users

No action required! Tart remains the default provider. Your existing commands will continue to work:

```bash
make build-vm
make install-dspace-all
```

### Switching to Vagrant

1. Install Vagrant and VirtualBox:
```bash
# macOS
brew install vagrant
brew install --cask virtualbox

# Linux
# Follow your distribution's instructions
```

2. Use Vagrant provider:
```bash
PROVIDER=vagrant make build-vm
PROVIDER=vagrant make install-dspace-all
```

3. Or set as default:
```bash
echo "PROVIDER ?= vagrant" > config.mk
make build-vm
```

### Using SSH for Existing Hosts

Connect to any SSH-accessible Ubuntu/Debian host:

```bash
# Physical server
PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host

# AWS EC2
PROVIDER=ssh SSH_HOST=ec2-xx-xx.compute.amazonaws.com SSH_USER=ubuntu make configure-host

# DigitalOcean
PROVIDER=ssh SSH_HOST=165.232.xx.xx SSH_USER=root make configure-host
```

## File Structure Changes

### Old Structure
```
ansible/
  inventory.ini    # Single static inventory
```

### New Structure
```
providers/         # Provider implementations
  tart.mk
  vagrant.mk
  ssh.mk
ansible/
  inventory/       # Provider-specific inventories
    tart.ini
    vagrant.ini
    ssh.ini
config.mk         # Provider selection
```

## Custom Inventory

If you had a custom `inventory.ini` with multiple hosts:

1. Your old file is preserved as `ansible/inventory.ini.old`
2. For SSH hosts, either:
   - Use environment variables: `PROVIDER=ssh SSH_HOST=myhost make install-dspace`
   - Or edit `ansible/inventory/ssh.ini` directly

## Troubleshooting

### "Provider not found" Error
Ensure `config.mk` exists and contains a valid provider:
```bash
echo "PROVIDER ?= tart" > config.mk
```

### Tart commands fail
Check that Tart is still installed:
```bash
brew list tart || brew install cirruslabs/cli/tart
```

### Can't connect to SSH host
Test the connection:
```bash
PROVIDER=ssh SSH_HOST=your-host make vm-status
```

## Benefits of the New Architecture

1. **Flexibility**: Choose the best provider for your environment
2. **Consistency**: Same commands work across all providers
3. **Portability**: Easily switch between local VMs and cloud servers
4. **Maintainability**: Clean separation of concerns

## Need Help?

- Check the updated README.md for detailed documentation
- Review provider-specific files in `providers/` directory
- Open an issue on GitHub for support