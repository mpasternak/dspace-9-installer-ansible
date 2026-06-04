# Data Migration Guide

How to move the contents of an existing DSpace installation onto a fresh server
provisioned with this repository.

Paths and names below match what this installer creates:

- **DSpace home:** `/opt/dspace` (CLI at `/opt/dspace/bin/dspace`, run as the `dspace` user)
- **Assetstore:** `/opt/dspace/assetstore` (local store)
- **Database:** PostgreSQL database `dspace`, role `dspace`, on `localhost:5432`
- **Solr:** `/var/solr/data` (service `solr`, port 8983)
- **Backend:** Apache Tomcat (`/opt/tomcat`, service `tomcat`, webapp on 8080)
- **Frontend:** PM2 app `dspace-ui` run as user `dspaceui`, behind nginx
- **Services:** `postgresql`, `tomcat`, `solr`, `nginx`

> **The DSpace version must match.** The fresh server must run the **same DSpace
> version** as the source (check with `sudo -u dspace /opt/dspace/bin/dspace version`;
> set `dspace_version` in `ansible/group_vars/all.yml`). If they differ,
> `dspace database migrate` (Step 3c) upgrades the schema.

## What holds DSpace state

A DSpace install is *software* + *data*. The installer provisions the software;
migration lays your data on top of it. The data lives in four places:

| # | Location | Migrate? |
|---|----------|----------|
| 1 | **PostgreSQL** (`dspace` DB) | **Required.** Metadata, items, collections, communities, accounts, groups, permissions, workflows, handles. Everything else is meaningless without it. |
| 2 | **Assetstore** (`/opt/dspace/assetstore`) | **Required.** The actual files (bitstreams). |
| 3 | **Solr `statistics` core** | Optional. Usage statistics — **not** rebuildable from the DB. The other cores (search/discovery, authority, oai, …) are rebuilt from the DB. |
| 4 | **Custom `config/` files** | As needed. Your customisations (`submission-forms.xml`, `item-submission.xml`, `config/modules/*`, `config/spring/*`, crosswalks, custom emails). **Do not** copy `local.cfg` wholesale — the installer generates a fresh one for the new host; port only your custom values. |

---

## Automated migration (same host, live legacy install)

If the legacy DSpace is **live on the same machine** as the fresh install (its
database in the local PostgreSQL, its own DSpace home / assetstore / Solr), two
Make targets automate the whole thing — no manual SQL or rsync:

```bash
# 1. Preview — reads the legacy install, changes nothing
make migrate-plan EXISTING=/path/to/legacy/dspace

# 2. Run it (interactive confirmation before anything destructive)
make migrate-from EXISTING=/path/to/legacy/dspace
#    Options:
#      WITH_STATS=1                  also migrate Solr usage statistics
#      CONFIRM=yes                   skip the interactive confirmation
#      START_AT="Restore database"   resume from a named step
```

You only point at the legacy DSpace home; its **DB name and assetstore path are
read from its `local.cfg`**. The legacy install is only **read** (a consistent
`pg_dump` snapshot + an assetstore copy); only the fresh install's empty `dspace`
database and assetstore are replaced, so the operation is reversible on the
legacy side.

The run is **resumable** — the database dump can be slow, so if a later step
fails, fix the cause and re-run with `START_AT="<step name>"`. On any failure the
installer prints the exact resume command for you. Playbook:
`ansible/migrate-local.yml`.

> This covers the **same-host, live** case. To move to a **different** server, or
> to restore from **backup files** (no live legacy DB), use the manual runbook
> below.

---

## Variant A — Migrate onto a fresh server

Three moves: **(1)** back up the source, **(2)** build a complete clean server
with this repo, **(3)** lay your data on top.

> The new server can be a brand-new VM **or any already-running Ubuntu/Debian
> host** you target with `PROVIDER=ssh` (see the README). "Already running" just
> means the OS is up — DSpace itself is installed fresh in Step 2.

### Step 1 — On the SOURCE server: back up

```bash
# Quiesce writes so the snapshot is consistent (the UI goes down briefly)
sudo systemctl stop tomcat
sudo -u dspaceui pm2 stop dspace-ui

# 1a. Database — the core of everything
sudo -u postgres pg_dump dspace | gzip > /tmp/dspace-db.sql.gz

# 1b. Assetstore (files). Small store -> tar; large -> rsync straight to the new host
sudo tar czf /tmp/dspace-assetstore.tgz -C /opt/dspace assetstore

# 1c. (Optional) Usage statistics — DSpace-native export (version-safe)
sudo -u dspace /opt/dspace/bin/dspace solr-export-statistics -i statistics
sudo tar czf /tmp/dspace-stats.tgz -C /opt/dspace solr-export

# 1d. Your config customisations (cherry-pick later — do NOT overwrite local.cfg)
sudo tar czf /tmp/dspace-config.tgz -C /opt/dspace \
  config/submission-forms.xml config/item-submission.xml \
  config/modules config/spring config/crosswalks config/emails 2>/dev/null

# 1e. Note these for later
sudo grep -E '^(handle\.prefix|dspace\.name)' /opt/dspace/config/local.cfg

# Bring the source back up if it should keep serving
sudo systemctl start tomcat && sudo -u dspaceui pm2 start dspace-ui

# Copy everything to the new server
scp /tmp/dspace-db.sql.gz /tmp/dspace-assetstore.tgz \
    /tmp/dspace-stats.tgz /tmp/dspace-config.tgz  admin@NEW_HOST:/tmp/
```

> If the source is also managed by this repo, `make backup-db` is a shortcut for 1a.

### Step 2 — On the NEW server: clean install with this repo

In `ansible/group_vars/all.yml` set `dspace_version` to match the source and
`domain_name` / `ssl_enabled` for the new host, then:

```bash
make build-vm install-complete
# Existing remote host instead of a VM:
#   PROVIDER=ssh SSH_HOST=NEW_HOST make configure-host install-complete
```

Log in once at the UI with `admin@localhost` / `admin` to confirm the empty
install works — this is your known-good baseline before importing.

### Step 3 — On the NEW server: import your data

```bash
# Stop everything that touches the DB / assetstore / Solr (PostgreSQL must stay up)
sudo systemctl stop tomcat solr
sudo -u dspaceui pm2 stop dspace-ui

# 3a. Database — replace the empty DB with your dump
sudo -u postgres psql -c "DROP DATABASE dspace;"
sudo -u postgres psql -c "CREATE DATABASE dspace OWNER dspace ENCODING 'UTF8';"
sudo -u postgres psql -d dspace -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
gunzip -c /tmp/dspace-db.sql.gz | sudo -u postgres psql -d dspace
#   The 'dspace' role + password (from the new host's local.cfg) are untouched;
#   ownership maps cleanly because the role is named 'dspace' on both servers.

# 3b. Assetstore — replace the empty one
sudo rm -rf /opt/dspace/assetstore
sudo tar xzf /tmp/dspace-assetstore.tgz -C /opt/dspace
sudo chown -R dspace:dspace /opt/dspace/assetstore

# 3c. Bring Solr up, then align the schema to the installed binaries
sudo systemctl start solr
sudo -u dspace /opt/dspace/bin/dspace database migrate

# 3d. (Optional) Import usage statistics
sudo tar xzf /tmp/dspace-stats.tgz -C /opt/dspace
sudo chown -R dspace:dspace /opt/dspace/solr-export
sudo -u dspace /opt/dspace/bin/dspace solr-import-statistics -i statistics

# 3e. Rebuild the search index FROM the restored DB (does not touch statistics)
sudo -u dspace /opt/dspace/bin/dspace index-discovery -b
# OAI users:  sudo -u dspace /opt/dspace/bin/dspace oai import -c

# 3f. Port over only YOUR config customisations: extract /tmp/dspace-config.tgz
#     elsewhere and copy individual files into /opt/dspace/config/. Do NOT
#     overwrite local.cfg — diff it against the source and move only the
#     settings you intentionally changed.

# 3g. Start the stack
sudo systemctl start tomcat
sudo -u dspaceui pm2 restart dspace-ui
```

### Step 4 — Finalise & verify

```bash
# Point the install at the new host's URL (from this repo)
make set-access-url URL=http://NEW_HOST          # or hostname / https

# Verify
sudo -u postgres psql -d dspace -tAc "SELECT count(*) FROM item;"   # should match the source
make check-services
```

- **Handle prefix:** the DB restore carries your `handle.prefix`; make sure the
  new host's `local.cfg` uses the same value. If the prefix itself changes,
  `dspace update-handle-prefix OLD_PREFIX NEW_PREFIX`. A standalone Handle.Net
  server is a separate migration (move its config and re-register with the
  global resolver).

---

## Gotchas

1. **Admin account:** after the DB restore the installer's `admin@localhost` /
   `admin` is gone — log in with your **source** accounts. Locked out?
   `sudo -u dspace /opt/dspace/bin/dspace create-administrator` adds a fresh
   admin to the restored DB.
2. **Drop/create before restore.** You cannot load a full dump onto the schema
   the installer already created — start from an empty database.
3. **Reindex discovery only.** Do **not** run `solr-reindex-statistics` during
   migration — it would wipe the statistics you just imported. `index-discovery -b`
   is safe (it only rebuilds the search core).
4. **Versions must match**, or rely on `dspace database migrate` to upgrade.
5. **Large assetstore →** use `rsync -a` instead of `tar` (resumable, faster).
6. **S3 assetstore →** don't copy files; set the same `assetstore.s3.*` in
   `local.cfg` and point at the same bucket.
7. **Consistent snapshot →** that's why Step 1 stops Tomcat on the source first.

---

## Variant B — Pointing the installer at an existing DSpace directory

**Short answer: not reliably, and not out of the box.** This installer is
greenfield-oriented:

- it owns a fixed layout (`/opt/dspace`, `/opt/tomcat`, `/var/solr`), creates the
  system users (`dspace`, `dspaceui`, `tomcat`, `solr`), templates **its own**
  `local.cfg`, initialises the database, runs `create-administrator`, and
  installs its own systemd services.

If you point it at a host that already runs a DSpace installed some other way, it
will not "adopt" that install — it lays its own layout alongside and/or
overwrites config, and the DB-init / `create-administrator` steps assume a fresh
database. If the existing server was built with **this same repo**, re-running
the provisioning targets is mostly idempotent, but `install-dspace` re-runs
`create-administrator` and a full rebuild — heavy and risky on a populated
database, so don't.

**Two supported paths:**

- **Same host, live legacy install** → the automated targets above
  (`make migrate-plan` / `make migrate-from`). This is the realistic
  "point at the existing install and migrate it" case.
- **Different server, or restoring from backup files** → Variant A (clean install
  + restore your data onto it).

What is *not* supported is having the installer **adopt an install in place** —
point at an existing `dspace.dir` and manage it directly, skipping user/DB
creation and reusing the existing config and database. That would be a larger
change to the provisioning roles; open an issue if you need it.

---

## Future tooling

The cross-server Variant A is a candidate for automation, e.g. `make backup-all`
(one tarball with DB + assetstore + statistics + config) and
`make restore BACKUP=...`. Not implemented yet — contributions welcome. (The
same-host case is already automated by `make migrate-from`.)
