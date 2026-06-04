# Design: Local migration of a live DSpace into the repo install

**Date:** 2026-06-04
**Status:** Approved

## Goal

On a **single host** that already runs a live legacy DSpace **and** a fresh
install provisioned by this repo (`/opt/dspace`), copy the legacy data into the
fresh install with one command. The user points at the legacy install directory;
everything else is derived. Two modes: **plan** (say what would happen, change
nothing) and **run** (do it), and the run is **resumable from any step** (the DB
dump is slow — a later failure must not force redoing it).

## Non-goals

- Cross-server / network transfer (it's all local on one box).
- Adopting an install in place (we restore *into* the repo's fresh DB).
- Migrating across DSpace major versions (same version assumed; `database
  migrate` handles minor schema drift).

## Vehicle

- New playbook `ansible/migrate-local.yml`, run against the active provider's
  target (same inventory as everything else).
- Two Makefile targets wrapping it.
- Reuses this session's resume infrastructure: Ansible `--start-at-task` for
  resuming, and the `resume_hint` callback which already prints the exact resume
  command when a task fails.

## Inputs

- `EXISTING=/path/to/legacy/dspace` (required) → `-e existing_dspace_dir=...`
- Derived from `{{ existing_dspace_dir }}/config/local.cfg`:
  - legacy DB name (parsed from `db.url`)
  - legacy assetstore dir (default `{{ existing_dspace_dir }}/assetstore`,
    overridable with `EXISTING_ASSETSTORE=`)
- Optional: `WITH_STATS=1` (Solr usage statistics), `START_AT="<step>"`,
  `CONFIRM=yes` (skip the interactive destructive gate).

## Make interface

```
make migrate-plan EXISTING=/old/dspace
    -> ansible-playbook migrate-local.yml -e existing_dspace_dir=... -e migrate_mode=plan
       (read-only: inspect + print the ordered plan + sizes + warnings)

make migrate-from EXISTING=/old/dspace [WITH_STATS=1] [START_AT="..."] [CONFIRM=yes]
    -> ansible-playbook migrate-local.yml -e existing_dspace_dir=... -e migrate_mode=run \
       [-e with_stats=true] [--start-at-task="..."] [-e confirm=yes]
```

## Steps (named tasks, resumable via START_AT)

1. **Inspect existing install** — parse legacy `local.cfg` (DB name, assetstore
   dir), gather sizes + Solr cores. (always; read-only)
2. **Plan** — print discovered values + the ordered actions + destructive
   warnings. In `plan` mode the play ends here (`meta: end_play`).
3. **Confirm** — interactive gate before destructive work (skipped if
   `confirm=yes`).
4. **Dump existing database** — `sudo -u postgres pg_dump <legacy_db> | gzip` to a
   work dir. (slow step)
5. **Export legacy Solr statistics** — *(WITH_STATS)* best-effort via the legacy
   install's `bin/dspace solr-export-statistics`.
6. **Restore database** — stop Tomcat; drop/recreate repo `dspace` DB; ensure
   `pgcrypto`; load the dump.
7. **Copy assetstore** — rsync legacy assetstore → `/opt/dspace/assetstore`,
   chown `dspace:dspace`.
8. **Import Solr statistics** — *(WITH_STATS)* into the repo install.
9. **Migrate schema** — `dspace database migrate`.
10. **Rebuild search index** — `dspace index-discovery -b`.
11. **Restart** — Tomcat + PM2 frontend.
12. **Verify** — item count from the repo DB.

Resume example: `make migrate-from EXISTING=/old/dspace START_AT="Restore database"`.
On failure the `resume_hint` callback prints the ready-to-paste resume command.

## Safety

- The legacy install is **read-only** in this flow: `pg_dump` takes a consistent
  MVCC snapshot (no need to stop it); the assetstore is copied, not moved. So the
  operation is reversible on the source side.
- Only the repo install's (empty) `dspace` DB is dropped/recreated.
- Destructive steps are gated by an interactive confirm (or `CONFIRM=yes`).

## YAGNI / deferred

- Solr statistics are **opt-in** (`WITH_STATS=1`). If the legacy and fresh
  installs share one Solr instance the `statistics` cores can collide; the plan
  warns about it. Default = DB + assetstore (the search core is rebuilt from the
  DB anyway).
- Custom `config/` files are not auto-copied — `docs/data-migration.md` covers
  the manual cherry-pick.

## Documentation

- Extend `docs/data-migration.md` with the automated single-host path
  (`migrate-plan` / `migrate-from`).
- Add the two targets to the README target table + CLAUDE.

## Testing

- `ansible-playbook --syntax-check`.
- Live **plan-mode** run against the repo's own `/opt/dspace` (read-only) to
  exercise the inspect/parse + plan output against a real `local.cfg`.
- The destructive path is validated by construction + review; a full end-to-end
  run requires a host with both a legacy and a fresh install (call this out, do
  not claim it was run live).
