---
name: update-dspace
description: >-
  Use when checking whether a newer DSpace release exists and bringing this
  installer up to it. Researches the latest DSpace stable (GitHub + LYRASIS
  wiki), pulls the official install requirements, compares the
  Java/Tomcat/Solr/PostgreSQL/Node matrix against this repo's pinned versions,
  classifies the upgrade as a simple version bump vs a heavier change, then
  guides the bump and validation. Designed to be run periodically (scheduled);
  stops early when already on the latest stable so a routine check is cheap.
---

# Update the DSpace installer to a new release

Keep this installer current with upstream DSpace. The job is **research →
classify → (maybe) bump → validate**. Most of the value is in deciding whether
the new release is a *cheap bump* (version numbers + a couple of fixes) or a
*heavier* change (new Java/Angular major, new deployment model, config/theme
changes) — and never claiming success without a **fresh** install proving it.

This skill encodes lessons from the 9.1 → 10.0 upgrade. Read it top to bottom on
the first run of a cycle.

## When to use / stop-early

Run this on a schedule (e.g. monthly) or when asked to "check for a new DSpace".
**Step 1 has a hard stop:** if the installer is already on the latest stable,
report "up to date" and END — do not pull docs or touch files. A routine check
must be cheap.

DSpace ships **two coordinated repos** that must move together:
`DSpace/DSpace` (backend) and `DSpace/dspace-angular` (frontend). They share the
same tag (e.g. `dspace-10.0`). Always treat them as one version.

---

## Step 1 — Current vs latest (stop if no newer stable)

**Current installed version:**
```bash
grep '^dspace_version:' ansible/group_vars/all.yml      # e.g. "10.0"
```

**Latest stable** — check both repos AND the wiki (the wiki is authoritative for
"what is the current stable / supported line"):
```bash
gh release list --repo DSpace/DSpace --limit 15
gh release list --repo DSpace/dspace-angular --limit 15
```
Also read the LYRASIS "Releases" page for the supported lines and the current
stable: <https://wiki.lyrasis.org/display/DSPACE/Releases>

Rules:
- Ignore pre-releases / release candidates (`-rc1`, `-beta`). Only **stable** tags.
- Confirm backend and frontend have a **matching** new tag.
- **STOP** if `latest_stable <= dspace_version`. Report the current state and end.
- If a newer stable exists, note **both** the new patch on the *current* major
  (e.g. 10.0 → 10.1, easy) and any new *major* (e.g. 10.x → 11.0, scrutinize).
  Prefer the latest patch of whichever major you target.

---

## Step 2 — Pull the official requirements & release notes

For the **target major** `N`, fetch (WebFetch) and extract the version/break
requirements from these LYRASIS wiki pages:

- Installing: `https://wiki.lyrasis.org/display/DSDOC<N>x/Installing+DSpace`
  → required **JDK**, **Tomcat** (or runnable-jar), **Solr**, **PostgreSQL**,
  **Node/Angular** for the backend & frontend.
- Release notes: `https://wiki.lyrasis.org/display/DSDOC<N>x/Release+Notes`
  → new features, **breaking changes**, dependency bumps.
- Upgrading: `https://wiki.lyrasis.org/display/DSDOC<N>x/Upgrading+DSpace`
  → migration steps, schema/config changes, deprecations.

Where to put findings: summarize them in your working notes / the plan you
present to the user (and the eventual commit message). Don't create scratch
files in the repo.

What to capture explicitly (you'll diff these against the repo in Step 3):
`JDK`, `Tomcat`, `Solr`, `PostgreSQL`, `Node`, `Angular`, deployment model
(WAR → Tomcat vs Runnable JAR), and any **frontend theme/config** changes.

---

## Step 3 — Build the version matrix & check the CDN

This installer pins component versions in `ansible/group_vars/all.yml` and keeps
the **version-coupled** ones in per-major profiles:
`ansible/vars/profiles/<major>.yml` (loaded via `include_vars` in the install
playbooks; they override `group_vars/all.yml`). `dspace_version`'s major selects
the profile (`10.0` → `10.yml`, `9.3` → `9.yml`).

Compare the doc's required versions against the repo:
```bash
grep -E 'java_version|tomcat_version|solr_version|postgres_version|nodejs_version' \
  ansible/group_vars/all.yml
sed -n '1,40p' ansible/vars/profiles/*.yml
```

| Component | Where it lives | Notes |
|---|---|---|
| `dspace_version` | `group_vars/all.yml` | the default; major picks the profile |
| `java_version` | profile (`10.yml`=21, `9.yml`=17) + `all.yml` default | **version-coupled** → belongs in the profile |
| `tomcat_version` | `all.yml` | pin to a **current** 10.1.x (see CDN note) |
| `solr_version` | `all.yml` | check it's still on the CDN |
| `nodejs_version` | `all.yml` (+ note in profile) | Angular dictates the min Node |
| `postgres_version` | `all.yml` | rarely changes |

**CDN check (real download-speed win + freshness).** Solr & Tomcat are pulled
"CDN-first, archive-fallback" (see `roles/{solr,tomcat}` + `apache_*_base` in
`all.yml`). `dlcdn.apache.org` keeps only the **current** release of each branch;
a pinned old patch gets purged → 404 → slow `archive.apache.org` fallback. Pin to
the **current** patch so it stays on the fast CDN:
```bash
# current Tomcat 10.1.x on the CDN:
curl -s https://dlcdn.apache.org/tomcat/tomcat-10/ | grep -oE 'v10\.1\.[0-9]+' | sort -uV | tail -1
# does our pinned version still resolve on the CDN? (200 good / 404 = bump it)
curl -s -o /dev/null -w '%{http_code}\n' -I \
  "https://dlcdn.apache.org/tomcat/tomcat-10/v<VER>/bin/apache-tomcat-<VER>.tar.gz"
```
Do the same for Solr (`https://dlcdn.apache.org/solr/solr/`).

---

## Step 4 — Classify: simple bump vs heavier change

Decide which bucket the upgrade is in. Be honest — guessing "simple" and
hitting a wall mid-install is worse than scoping it up front.

**SIMPLE (version numbers + small fixes)** — when, vs the current install:
- Same **JDK** major, same **Tomcat** major (10.1.x → 10.1.y is fine),
  same Solr major, same deployment model.
- Frontend is the same Angular major, or a minor bump with no theme-config break.
- Then it's: bump `dspace_version`, refresh `tomcat_version`/`solr_version` to the
  current patch, update docs — done.

**HEAVIER (needs real work + scrutiny)** — any of:
- **New JDK major** (e.g. 17 → 21): add/adjust the **version profile**
  (`vars/profiles/<major>.yml: java_version`) and verify the `java` + `tomcat`
  roles' JVM paths still resolve (`jvm_arch`).
- **New Angular major** on the frontend: theme config and the build can break
  (this is what bit 9 → 10; see gotchas). Read the frontend release notes.
- **Tomcat major** change, **Solr major** change, or a **deployment-model**
  change (WAR → runnable JAR).
- DB **schema**/config migrations called out in "Upgrading DSpace".

If HEAVER: stop and write a short plan (what changes per role/profile) before
editing. If SIMPLE: proceed to Step 5.

---

## Step 5 — Apply a simple bump

1. **Version profile first** if the major changed: add
   `ansible/vars/profiles/<newmajor>.yml` (copy the closest existing one, set
   `java_version` and any Node/build deltas; only put values that DIFFER between
   majors). The major of `dspace_version` must match a profile filename.
2. **`group_vars/all.yml`**: set `dspace_version` to the new version, and the
   `all.yml` defaults (`java_version`, `tomcat_version`, `solr_version`, ...) to
   match the **default** target. Keep `all.yml` and the default profile in sync.
3. **Docs**: update the "Key Variables" blocks and stack tables that quote
   versions — `CLAUDE.md`, `docs/configuration.md`, `docs/reference.md`,
   `README.md`. (`grep -rn '<oldver>' .` to find them all.)
4. **Lint**: `make lint` must stay green (profile `production`, run from
   `ansible/`). It is also the CI lint gate.
5. **Commit** with a message that records the researched requirements and what
   changed.

---

## Step 6 — Validate (a FRESH install, not a re-run)

This is non-negotiable. **Re-running an install on an already-configured VM
hides whole classes of bugs** — handler/notify mismatches and other
"changed-only" behavior never fire when tasks report `ok`. Validate on a clean
build:

```bash
# local, Tart (arm64): destroy and rebuild from scratch
echo yes | PROVIDER=tart make destroy-vm
PROVIDER=tart make build-vm install-complete

# CI does the authoritative fresh install on amd64 (Docker) on push to main:
gh run watch <run-id> --exit-status
```

Green means: prerequisites (ufw, java, postgres, nginx, tomcat, solr) + backend
(Maven build, DB migrate, admin) + frontend (npm build, SSR up) all pass, and
`http://<host>/` (UI via nginx) + `/server/api` (backend) return 200.

The CI workflow runs on every push to `main`; it takes ~30 min for a full
install. If the docker-test fails, `gh run view --log` truncates long output —
get the real error from the failure **artifact** (`gh run download <id>`,
`ci-logs/system.log`) or the raw job log
(`gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs`).

---

## Known gotchas (learned the hard way on 9 → 10)

- **Frontend theme name must be a real theme.** In
  `roles/dspace-frontend/templates/config.prod.yml.j2`, `themes[].name` must be a
  theme that exists under the frontend's `src/themes/` (`base`/`custom`/`dspace`)
  — NOT the site title. DSpace 10's SSR eagerly reads `<name>-theme.css` at boot
  and crashes (ENOENT, PM2 "errored") if it doesn't exist. Use `dspace`.
- **Don't FQCN `become_method`.** ansible-lint's schema may prefer
  `ansible.builtin.sudo`, but some ansible-core builds (CI's) reject the FQCN
  form at runtime and the postgres become fails. Omit `become_method` (default
  is `sudo`).
- **Keep `notify:` in sync with handler names.** ansible-lint's `name[casing]`
  capitalizes handler names; `notify:` strings must match exactly or you get
  "handler not found" on a fresh install. (This only shows on a fresh run.)
- **Bump purged Apache pins.** A Tomcat/Solr patch that fell off `dlcdn` forces
  the slow archive path; pin to the current patch (Step 3).
- **SSR cold start is slow.** `roles/dspace-frontend/tasks/build.yml` waits for
  `:4000`; a fresh, cold SSR start can exceed a tight timeout even when healthy —
  keep the `wait_for` generous (≥180s).
- **Validate Apache mirror folds.** If you template an OpenSSL `-subj` or any
  multi-line var, confirm it renders exactly (PyYAML) — a stray fold-space breaks it.

---

## Cyclic usage

Run periodically and cheaply:
- Schedule it (e.g. `/schedule` a monthly routine, or a cron that invokes this
  skill). The Step-1 stop-early keeps a "nothing new" run to a couple of API calls.
- A run either ends with **"up to date"**, a **plan** (heavy upgrade — needs a
  human decision), or a **bump PR/commit + green fresh-install validation**.
- Never report success on docs research alone — only a green **fresh** install
  (local Tart and/or CI) counts.
