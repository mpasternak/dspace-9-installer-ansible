# Quick Start

## TL;DR

```bash
# 1. Build a VM and install the complete stack (backend + frontend + nginx)
make build-vm install-complete

# 2. Access your installation
#    Frontend: http://dspace-server/
#    Backend:  http://dspace-server/server

# 3. When done, clean up
make destroy-vm
```

The default provider is **Tart** (macOS). To use another, set `PROVIDER=` — see
[Providers](providers.md).

## Recommended workflow

=== "Tart / OrbStack (macOS)"

    ```bash
    make configure-developer-machine     # install deps + create the VM
    make install-complete                # backend + frontend + nginx
    make open-browser                    # open the UI
    ```

    For OrbStack, prefix everything with `PROVIDER=orbstack`.

=== "SSH (existing server)"

    ```bash
    PROVIDER=ssh SSH_HOST=1.2.3.4 make configure-host install-complete
    ```

=== "local-linux (this machine)"

    ```bash
    # Run ON a dedicated Ubuntu/Debian host
    PROVIDER=local-linux make build-vm install-complete
    ```

## Log in

The installer creates an administrator account:

- **Email:** `admin@localhost`
- **Password:** `admin`

In the UI: top-right **Log In** → email/password. Then create communities and
collections and start submitting items.

!!! warning "Change the default password"
    `admin/admin` is a development default. For anything exposed, change
    `dspace_admin_password` in `ansible/group_vars/all.yml` before installing, or
    change it later in the UI.

## "Service Unavailable" after install?

The UI must be reached at the URL it's configured for. If you open it by a
different host/scheme than configured, the in-browser API calls fail and the app
shows *Service Unavailable*. The fix is one command:

```bash
make set-access-url URL=http://your-host
```

See [Configuration → Access URL](configuration.md#access-url) and
[Troubleshooting](troubleshooting.md#service-unavailable).
