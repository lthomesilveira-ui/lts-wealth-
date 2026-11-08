# Offline logical recovery rehearsal

This tool prepares the independent recovery test without creating a paid project,
copying production credentials to a cloud test service, or starting production
integrations. It consumes files already exported by an authorized official route.
It does not export a database, request secrets, contact production or restore into
an existing cluster. No frontend release or production migration is required.

## Input

Use the official [Supabase CLI backup and restore workflow](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
and [platform-to-self-hosted guide](https://supabase.com/docs/guides/self-hosting/restore-from-platform)
for `roles.sql`, `schema.sql` and `data.sql`. Production export requires an existing
authorized database connection; this repository contains no credentials or dumps.
Do not revive a custom bulk-export endpoint or use a test cloud service as transit.

Provide `acceptance.sql` with independently derived checks for the captured source:
table coverage, complete observation history, Auth records, RLS/grants, audit and
notification journals, financial results and all required database consumers.
Counts alone do not prove identical values. Source inventories and expected
results must share the export's consistent snapshot; unrelated daily snapshots
must not be combined and certified as a single capture.

The acceptance script must create `public.lts_recovery_acceptance` with exactly
one row for every component declared `covered_by_sql_acceptance`. Each row contains
`component text`, `passed boolean` and a lowercase 64-character
`evidence_sha256`. The digest identifies the independently derived expectation
set used by that component; it must not contain source values. Missing, duplicate,
failed, extra or malformed rows make the rehearsal fail. This prevents a generic
successful SQL script from being mistaken for complete declared coverage.
The manifest must independently bind each SQL-covered component to its expected
digest in `sql_acceptance_evidence_sha256`. A digest emitted only by
`acceptance.sql` is self-declared and is rejected when it differs from that
frozen expectation.

A private `manifest.json` must contain `data_kind` (`production` or `synthetic`)
and a `sha256` mapping for exactly those four files. It must also identify one
consistent capture and declare the status of every recovery component: database
history, Auth records, Storage metadata, Storage object bytes, roles/grants/RLS,
application consumers, and replay/cache. The accepted states are
`covered_by_sql_acceptance`, `separate_evidence_required`, and `not_captured`.
Database history must be covered by the SQL acceptance file. Missing components
remain explicit; declaring them does not verify them or turn a partial rehearsal
into full recovery.

```json
{
  "data_kind": "production",
  "capture": {
    "id": "private-capture-id",
    "captured_at": "2026-11-07T10:50:37Z",
    "consistent_snapshot": true
  },
  "recovery_scope": {
    "database_history": "covered_by_sql_acceptance",
    "auth_records": "covered_by_sql_acceptance",
    "storage_metadata": "covered_by_sql_acceptance",
    "storage_object_bytes": "separate_evidence_required",
    "roles_grants_rls": "covered_by_sql_acceptance",
    "application_consumers": "separate_evidence_required",
    "replay_and_cache": "not_captured"
  },
  "sql_acceptance_evidence_sha256": {
    "database_history": "...",
    "auth_records": "...",
    "storage_metadata": "...",
    "roles_grants_rls": "...",
    "application_consumers": "..."
  },
  "sha256": {
    "roles.sql": "...",
    "schema.sql": "...",
    "data.sql": "...",
    "acceptance.sql": "..."
  }
}
```

The files are copied to a new private directory and checked against their hashes
before any SQL is executed. The expected SQL evidence mapping must contain exactly
the components declared as covered by SQL, with lowercase SHA-256 values; missing,
extra, malformed or mismatched expectations fail closed. The receipt preserves the capture declaration and
lists SQL-covered components, components requiring separate evidence, and
components not captured at all. The capture timestamp must be valid ISO 8601 and
include a timezone. The compatibility list of all components outside SQL coverage
is retained for existing receipt consumers. The manifest is an integrity record,
not a source-authenticity attestation.

Before handing the input directory to this tool, retain the exact SHA-256 of
`manifest.json` through an independent authorized channel. Supplying a digest
calculated from the same untrusted directory at execution time defeats this guard.
The rehearsal rejects a manifest changed after that digest was retained and copies
the exact verified manifest bytes into the private output. This detached digest
binds the bundle presented to the rehearsal; it is not a digital signature and
does not by itself prove source authenticity.

Use a PostgreSQL 17 runtime with every extension and managed-schema prerequisite
needed by the official export. Missing extensions are a hard failure. Never strip
an extension, grant, trigger or protected dataset to make the test pass.

## Execution

```sh
python3 backend/tools/isolated_restore/restore.py \
  --input /absolute/private/export \
  --output /absolute/private/new-rehearsal \
  --pg-bin /absolute/postgresql/17/bin \
  --manifest-sha256 independently-retained-lowercase-sha256
```

The host must permit an unprivileged Linux user/network namespace. The command
fails closed when isolation cannot be established. Both IPv4 and IPv6 must report
no route before startup. PostgreSQL listens only on a private Unix socket,
preloaded background workers are disabled, and imported cron jobs are deactivated
inside the isolated copy. Triggers are disabled only during the transactional data
import. Connection credentials and PostgreSQL startup overrides are not inherited.
The command never accepts a destination database URL or reuses an existing output.

The server is stopped after success or failure. The stopped cluster, immutable
input copy, private log and `receipt.json` remain in the private output directory.
Keep this directory outside source control and outside any published artifact.
Raw logs can contain sensitive source values. Receipts expose only verification
state, runtime settings and hashes, including the structured SQL evidence matrix.
They always keep whole-app certification false.

## Verification and remaining boundary

```sh
LTS_RESTORE_PG_BIN=/absolute/postgresql/17/bin \
  python3 -m unittest discover -s backend/tools/isolated_restore -p test_restore.py -v
```

Native tests use invented data: roles, RLS, Auth-shaped records, Storage metadata,
history totals, a reader, a trigger that must not run, and active jobs that must be
disabled. Failure cases include altered inputs, symlinks, missing acceptance,
unsafe network context, reused outputs, failed assertions and absent extensions.
These tests do not use real accounts or certify cross-owner HTTP isolation.

Passing the database rehearsal is one recovery substep. A full recovery claim
still requires an authorized complete production export, independent source
comparisons, actual Auth/API behavior, separately recovered Storage object bytes,
and the remaining application consumers and replay/cache checks. An offline local
copy or a synthetic test cannot close those criteria.

