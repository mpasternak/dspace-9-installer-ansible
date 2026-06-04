# Operations

Day-to-day tasks for a running install. All work across every provider.

## Open in a browser

The host is resolved from the active provider, so these just work:

```bash
make open-browser     # frontend, http://<host>/
make open-api         # backend,  http://<host>/server/  (REST/HAL browser)
make open-solr        # Solr admin, http://<host>:8983/solr/

# Overrides
make open-browser BROWSER_PATH=server/api
make open-browser URL=http://1.2.3.4:8983/solr
```

Opener: `open` (macOS) → `xdg-open` (Linux) → `wslview` (WSL).

## Services & status

```bash
make check-services       # postgresql, tomcat, solr
make vm-status            # provider/host status
make frontend-status      # PM2 frontend status
```

## Logs

`tail-logs` and `frontend-logs` **follow logs live** (Ctrl+C to stop):

```bash
make tail-logs                                     # backend (default /opt/dspace/log/dspace.log)
make frontend-logs                                 # frontend (PM2 dspace-ui)

# Any file via LOG_FILE; initial lines via LINES
make tail-logs LOG_FILE=/opt/tomcat/logs/catalina.out
make tail-logs LOG_FILE=/var/log/nginx/error.log LINES=100
```

!!! note "Where the backend actually logs"
    The Spring Boot backend runs in Tomcat; its console output is in
    `/opt/tomcat/logs/catalina.out`. If `/opt/dspace/log/dspace.log` is empty,
    look there (`make tail-logs LOG_FILE=/opt/tomcat/logs/catalina.out`).

These use `tail -F`, so they wait/retry if a file doesn't exist yet.

## Frontend management

```bash
make frontend-restart     # restart the PM2 process
make frontend-status
make remove-frontend      # remove the frontend (backend stays)
```

## Run an arbitrary command on the target

```bash
make provider-exec REMOTE_CMD="uptime"
```

This is the primitive behind live log following — it runs a command over the
provider's native connection (SSH, `orb`, `vagrant ssh`, or locally).

## Backups & database

```bash
make backup-db                                          # pg_dump | gzip to /tmp
sudo -u postgres psql -d dspace                         # open a psql shell (on the host)
```

For moving a whole install, see [Data Migration](data-migration.md).

## Resuming a failed run

When an Ansible run stops on a failed task, the installer prints — right after the
play recap — the failed task name and a ready-to-paste command to resume from that
point:

```bash
# from the project's ansible/ directory
ansible-playbook -v -i inventory/<provider>.ini install-prerequisites.yml \
    --start-at-task="Download Solr"
```

!!! note "Resume safely"
    Resuming only works if the task doesn't depend on something an earlier
    (now-skipped) task set up. If you hit "undefined variable" errors, just re-run
    the whole step — Ansible is idempotent, so finished work is skipped. The hint
    shows both commands.

## Changing the access URL

```bash
make set-access-url URL=http://your-host
```

See [Configuration → Access URL](configuration.md#access-url).
