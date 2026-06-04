# Providers

A *provider* is the target where DSpace gets installed. Every `make` target works
the same regardless of provider — you only choose one with `PROVIDER=` (or set the
default in `config.mk`).

| Provider | Host OS | Target | Use for |
|----------|---------|--------|---------|
| `tart` (default) | macOS | Native VM (Apple Virtualization) | Fast local dev on macOS |
| `orbstack` | macOS | OrbStack Linux machine | Fast local dev on macOS |
| `vagrant` | any | VirtualBox/VMware VM | Cross-platform local dev |
| `ssh` | any | Existing Ubuntu/Debian host | Cloud / physical servers |
| `docker` | any | Ubuntu container | CI testing |
| `local-linux` | Linux | The machine running `make` | Install onto a dedicated server itself |

```bash
PROVIDER=orbstack make build-vm install-complete   # one-off
echo 'PROVIDER ?= orbstack' >> config.mk            # or set the default
```

## Tart (macOS)

Native macOS virtualization (Apple Silicon / Intel). Lightweight and fast.

```bash
make configure-developer-machine     # installs Tart, creates the VM
make install-complete
make ssh                             # ssh admin@<vm-ip>
make destroy-vm
```

`TART_IMAGE` and `VM_NAME` are configurable. The Tart provider also manages an
`/etc/hosts` entry for the VM (`make hosts-add` / `hosts-check` / `hosts-remove`).

## OrbStack (macOS)

[OrbStack](https://orbstack.dev) runs fast, lightweight Linux machines on macOS.
It manages SSH keys automatically and shares host resources dynamically — so
there is **no key-copy and no VM-sizing step**.

```bash
PROVIDER=orbstack make configure-developer-machine install-complete
PROVIDER=orbstack make ssh          # equivalent to: ssh dspace-server@orb
PROVIDER=orbstack make destroy-vm

# Optional: a different base image (default ubuntu:noble)
PROVIDER=orbstack ORBSTACK_IMAGE=ubuntu:jammy make build-vm
```

!!! info "How the connection works"
    OrbStack exposes machines via its `orb` SSH host. The inventory connects as
    `<machine>@orb` (the default user, which has passwordless sudo); roles escalate
    with `become`.

## Vagrant (cross-platform)

Works on Windows, macOS and Linux with VirtualBox or VMware.

```bash
PROVIDER=vagrant make configure-developer-machine install-complete
PROVIDER=vagrant make destroy-vm
```

Configurable: `VAGRANT_BOX`, `VAGRANT_CPUS`, `VAGRANT_MEMORY`.

## SSH (existing servers)

Install onto any reachable Ubuntu/Debian host — cloud (AWS/Azure/GCP/DigitalOcean)
or physical.

```bash
PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host install-complete

# Cloud instance with a non-default user
PROVIDER=ssh SSH_HOST=ec2-…amazonaws.com SSH_USER=ubuntu make configure-host
```

`destroy-vm` is a no-op for SSH (it won't delete your server). Required:
`SSH_HOST`; optional: `SSH_PORT` (22), `SSH_USER` (admin).

## Docker (CI)

Used by the GitHub Actions test pipeline. Ubuntu 24.04 base with systemd, SSH on
port 2222. Mostly for automated testing.

```bash
PROVIDER=docker make build-vm install-complete
```

## local-linux (loopback)

Installs DSpace **onto the machine running `make`**, via Ansible's local
connection — no VM, no SSH.

```bash
PROVIDER=local-linux make build-vm install-complete
```

!!! warning "Linux-only, and it modifies this machine"
    Debian/Ubuntu only — it **refuses to run on macOS** (use `tart`/`orbstack`)
    and requires **passwordless sudo**, both checked before anything runs.
    `build-vm` also runs system updates that may **reboot the host**, so use a
    dedicated machine/VM. `start-vm`/`stop-vm`/`destroy-vm` are no-ops.
