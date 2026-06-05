# DSpace Installer

[![Test DSpace Installation (Docker)](https://github.com/mpasternak/dspace-installer/actions/workflows/test-docker-installation.yml/badge.svg)](https://github.com/mpasternak/dspace-installer/actions/workflows/test-docker-installation.yml)

Ansible-based automation for installing DSpace on local VMs, macOS Linux
machines, existing SSH hosts, CI containers, or a dedicated Linux host.

Full documentation: <https://mpasternak.github.io/dspace-installer/>

## TL;DR

```bash
# Build a target and install the complete stack: backend + frontend + nginx
make build-vm install-complete

# Open the DSpace frontend
make open-browser

# Remove the local VM/machine when using a VM provider
make destroy-vm
```

The default provider is `tart` on macOS. To use another target:

```bash
PROVIDER=orbstack make build-vm install-complete
PROVIDER=vagrant make build-vm install-complete
PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host install-complete
PROVIDER=local-linux make build-vm install-complete
```

## What It Does

- Installs a complete DSpace stack with PostgreSQL, Solr, Tomcat, nginx, and the
  Angular frontend.
- Uses one `make` interface across Tart, OrbStack, Vagrant, SSH, Docker, and
  local Linux targets.
- Supports released DSpace versions and GitHub branches for both backend and
  frontend.
- Includes operational helpers for logs, service checks, browser shortcuts,
  access URL changes, database backups, and same-host data migration.

## Providers

| Provider | Target | Typical use |
|----------|--------|-------------|
| `tart` | macOS native VM | Fast local development on macOS |
| `orbstack` | OrbStack Linux machine | Lightweight macOS Linux target |
| `vagrant` | VM via VirtualBox/VMware | Cross-platform local development |
| `ssh` | Existing Ubuntu/Debian host | Cloud or physical servers |
| `docker` | Ubuntu container | CI testing |
| `local-linux` | The machine running `make` | Dedicated Ubuntu/Debian host |

See [Providers](docs/providers.md) for setup details and provider-specific
requirements.

## Requirements

Control machine:

- `make`
- SSH client
- Python 3
- Ansible, installed directly or by `make configure-developer-machine`
- Provider tooling as needed, such as Tart, OrbStack, Vagrant, or Docker

Target host:

- Debian-family Linux, currently Debian/Ubuntu only
- sudo privileges, usually passwordless for automation
- At least 4 GB RAM, 8 GB recommended
- At least 20 GB free disk space
- Network access for package and source downloads

## Documentation

- [Quick Start](docs/quickstart.md) - install the full stack in a few commands
- [Providers](docs/providers.md) - choose and configure a target
- [Installation](docs/installation.md) - installation phases and version choices
- [Configuration](docs/configuration.md) - versions, access URL, firewall, SSL
- [Operations](docs/operations.md) - logs, browser shortcuts, backups, services
- [Data Migration](docs/data-migration.md) - move an existing DSpace install
- [Troubleshooting](docs/troubleshooting.md) - common failures and fixes
- [Reference](docs/reference.md) - Make targets, playbooks, paths, structure

## Common Commands

```bash
make help                         # list available targets
make info                         # show active provider configuration
make install-complete             # backend + frontend + nginx
make set-access-url URL=http://host
make check-services
make tail-logs
make backup-db
```

## Contributing

Contributions are welcome. Open an issue for bugs, provider support requests, or
installation gaps, or send a pull request with a focused change.

## License

MIT License. See [LICENSE](LICENSE).
