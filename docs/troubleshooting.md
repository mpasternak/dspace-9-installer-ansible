# Troubleshooting

## Service Unavailable

**Symptom:** the frontend loads but shows *Service Unavailable* (or "500"), even
though every service is up and `curl http://<host>/` returns a full page.

**Cause:** the UI is being accessed by a different URL than it's configured for.
The server-rendered HTML loads fine (so `curl` looks healthy), but the browser's
follow-up API calls go to the *configured* REST URL — and a mismatch (wrong host,
HTTP↔HTTPS mixed content, or a CORS origin that isn't allowed) makes them fail, so
the app renders its error page.

**Diagnose:** open the browser DevTools (F12) → Console / Network. You'll see the
failed API calls (`ERR_NAME_NOT_RESOLVED`, "blocked by CORS", or "Mixed Content").
Server logs stay empty because the server is healthy — the failure is client-side.

**Fix:** point the install at the URL you actually use:

```bash
make set-access-url URL=http://your-host          # or hostname / https
```

If you reach the host by name, make sure it resolves (e.g. `make hosts-add` for the
Tart provider, or a real DNS/`/etc/hosts` entry).

## Backend log file is missing / empty

`/opt/dspace/log/dspace.log` may be empty if the `tomcat` user can't write to
`/opt/dspace/log`. The Spring Boot backend then logs to Tomcat's console instead:

```bash
make tail-logs LOG_FILE=/opt/tomcat/logs/catalina.out
```

## Provider-specific

=== "Tart"

    ```bash
    brew list tart || brew install cirruslabs/cli/tart
    tart list
    make vm-status
    make destroy-vm && make build-vm     # recreate
    ```

=== "OrbStack"

    ```bash
    command -v orbctl || brew install orbstack
    orbctl list
    make vm-status
    ssh dspace-server@orb                 # connect manually
    ```

=== "SSH"

    ```bash
    PROVIDER=ssh SSH_HOST=your-host make vm-status
    ssh user@host "sudo -n true" || echo "sudo needs a password"
    ANSIBLE_VERBOSE=-vvv PROVIDER=ssh SSH_HOST=your-host make install-dspace
    ```

=== "local-linux"

    ```bash
    # Must run ON the Debian/Ubuntu target (refuses on macOS)
    PROVIDER=local-linux make vm-status
    sudo -n true && echo OK || echo "add NOPASSWD sudo for your user"
    ```

## Build / install failures

```bash
java -version                 # should be 17
export MAVEN_OPTS="-Xmx2048m" # if the Maven build runs out of memory
make dspace-rebuild           # rebuild + reinstall (skips download)
```

A failed Ansible run prints a resume command — see
[Operations → Resuming a failed run](operations.md#resuming-a-failed-run).

## Database checks

```bash
sudo systemctl status postgresql
sudo -u postgres psql -l
sudo -u postgres psql -d dspace -c "\du"      # roles
```

## Common gotchas

- **Ports in use:** 8080 (Tomcat), 8983 (Solr), 4000 (frontend) must be free.
- **Frontend build is slow:** 10–15 minutes is normal.
- **Resources:** ≥ 4 GB RAM; the Solr/Tomcat startup can OOM on small VMs.
- **Full reset:** `make destroy-vm && make build-vm` (VM providers).
