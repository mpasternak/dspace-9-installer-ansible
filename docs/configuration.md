# Configuration

Most settings live in **`ansible/group_vars/all.yml`**. Edit it before installing,
or use the dedicated targets below for a running install.

## Key variables

```yaml
dspace_version: "10.0"
dspace_install_dir: "/opt/dspace"
postgres_version: "16"
java_version: "21"
solr_version: "9.10.1"
tomcat_version: "10.1.33"
nodejs_version: "20"
domain_name: "dspace-server.localnet"   # change to your real domain
ssl_enabled: false                       # true once you have a valid domain
```

The admin account is created from:

```yaml
dspace_admin_email: "admin@localhost"
dspace_admin_password: "admin"           # change for anything non-local
```

## Access URL

DSpace must be reached at the URL it is configured for. The browser uses that URL
for its API calls, so opening the site by a different host or scheme breaks the UI
with a *Service Unavailable* page (the server-rendered HTML still loads, which is
why it can look fine in `curl`).

To re-point a **running** install at a URL:

```bash
# Access by IP over HTTP (no /etc/hosts entry needed)
make set-access-url URL=http://192.168.64.11

# By hostname / real domain
make set-access-url URL=https://dspace.example.org
```

This rewrites the backend (`dspace.ui.url`, `dspace.server.url`, CORS) and the
frontend (`rest` host/port/ssl), then restarts Tomcat and the frontend. It is
idempotent.

!!! warning "HTTPS with a self-signed certificate"
    The SSR server (Node) must trust the REST API's certificate. Use a
    properly-issued certificate (e.g. Let's Encrypt via the `certbot` role) or add
    your dev CA to the host trust store. **Do not** disable TLS verification
    (`NODE_TLS_REJECT_UNAUTHORIZED=0`) — that exposes SSR↔API traffic to MITM. For
    local dev, the `http://<host>` form avoids this entirely.

## Firewall (UFW)

`install-prerequisites` configures the host firewall via the `ufw` role. SSH (22),
HTTP (80), HTTPS (443) and the Handle ports (2641) are always allowed; development
and debug ports open based on the mode.

```yaml
firewall_enabled: true            # set false to skip firewall configuration
firewall_mode: "development"      # production | development | all
ufw_default_incoming: "deny"
ufw_default_outgoing: "allow"
ufw_default_routed: "deny"
```

| Mode | Also opens |
|------|------------|
| `production` | (only the always-on ports) |
| `development` | Tomcat 8080/8000, frontend 4000 |
| `all` | + Solr 8983, PostgreSQL 5432 (debug) |

## SSL / TLS

With `ssl_enabled: false` (default) the installer can use a self-signed
("snakeoil") certificate (`use_snakeoil: true`). For a real certificate, set a
valid `domain_name`, `ssl_enabled: true`, and use the `certbot` role
(Let's Encrypt).

## Frontend REST endpoint

The frontend's REST target is templated from these (defaults preserve the
`http://<domain_name>:80` behaviour; `set-access-url` overrides them):

```yaml
dspace_rest_ssl: "{{ ssl_enabled }}"
dspace_rest_host: "{{ domain_name }}"
dspace_rest_port: "{{ 443 if ssl_enabled | bool else 80 }}"
dspace_rest_namespace: "/server"
```
