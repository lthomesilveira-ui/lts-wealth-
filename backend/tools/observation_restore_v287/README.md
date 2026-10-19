# Typed observation recovery check

Offline verification of a preverified decoded collection in a new local
PostgreSQL WebAssembly database (PGlite). This tool contacts no project endpoint,
reads no credentials, and has no production SQL or deletion interface.
Existing database and report paths are refused.

This is one recovery component. It does not restore the full application,
Auth, Storage binaries, current production state or the eight application
consumers. It does not remove or compact production observations. The V248
archive/compression proposal remains the separate draft PR113.

## Use and trust boundary

Install the locked dependency with npm ci --ignore-scripts in this directory.
Run node typed_restore.mjs with these explicit arguments:

- --data-dir: a new local directory.
- --report: a new JSON report path.
- --owner and --project: independently trusted scope values.
- --inventory-sha256: the retained inventory hash.
- --expected-rows and --expected-runs: independently retained collection counts.

Stdin is newline-delimited JSON: one inventory frame; one run frame per verified
closed run; and a verified_collection end frame. Inventory carries owner_id,
source_project, inventory_sha256, rows and runs. Each run carries run_id,
exact PostgreSQL metadata text, row_count, independent source_vectors_sha256,
and the decoded rows. The end frame carries rows, runs, all_12_fields_equal,
independent_sql_source_hashes_verified and full_inventory_covered (all true).

The caller must first verify the archive checksum ledger, independent original
exports, complete inventory membership and exact metadata. This tool checks
typed recovery of that verified input. A hash supplied by untrusted input does
not establish its origin or act as a signature.

Every row contains twelve strings: id, user_id, connection_id, sync_run_id,
resource_type, provider_record_id, raw_hash, raw_payload, normalized_payload,
reconciliation, ingest_action, observed_at. Financial payloads remain PostgreSQL
text and never become JavaScript floating-point amounts. Failed/partial run
counters and empty closed runs are preserved.

## Verification and limits

The reconstructed table uses UUID, JSONB, timestamptz, NOT NULL, primary/unique
keys, action checks and foreign keys to reference-ID parent tables. Parent IDs
are not restored users or connections. Queries use parameters. Each run import
and its source-vector comparison are atomic. An incomplete collection never
produces a PASS receipt; its new private database can remain for diagnosis.

The native SQL SHA256 follows the original ordered twelve-field text-vector
contract. Exact metadata text is compared too. The tool tests a local mutation
with ROLLBACK, rejects duplicate observation IDs, explicitly checkpoints, closes
and reopens the database, and checks the complete count and every run again.

The engine is locked to the application's PostgreSQL 17 major version. Updating
the dependency requires repeating persisted private-collection compatibility
checks. The recorded build/version is PGlite, not a native Supabase server restore.
full_database_restore, native_server_restore, storage_binary_restore,
eight_application_consumers_verified and current_production_snapshot remain
false. Rebuilt size describes only this component, not full production headroom.
No original source file is overwritten or deleted.

Run node --test typed_restore.test.mjs rls_role_probe.test.mjs for synthetic
precision, failure and role-isolation cases.
CI uses synthetic data only. Never commit bank exports, real owner/run IDs,
private checksums, recovery databases or private reports.

Large retained-collection probes have failed the persistence/reopen checks in
the current isolated Work environment. Successful in-process comparisons and
the synthetic tests are not a complete restoration acceptance. Keep the failed
probes, do not remove originals, and use an authorized native PostgreSQL/Storage
environment for full recovery and consumer acceptance. The checker deliberately
fails without writing a PASS receipt when persistence cannot be verified.

## Separate read-only role probe

rls_role_probe.sql uses an authorized administrative database connection to
check owner-scoped public tables under anonymous/no-identity and synthetic
foreign-identity PostgreSQL roles. It reads counts only, excludes Health,
restores the execution role, returns bounded per-table results and rolls back.
It creates no role, user, policy or record. Its fixtures prove that it accepts
owner-isolated rows and detects unrestricted foreign reads. These role/claims
tests do not establish signed HTTP sessions, administrative Auth configuration
or Storage access.

## Bounded helper permission patch

../../patches/v287/pending_helpers_private.sql revokes only PUBLIC/anon/
authenticated execution of two unused invoker pending-card helpers. It retains
their existing owner/service access and verifies exact definition fingerprints
and unchanged function identity. It executes no pending reconciler and writes
no financial data. Confirm current callers and role tests before applying it.
pending_helpers.test.mjs covers both browser denials, service continuity,
idempotence and atomic rejection of definition drift with synthetic fixtures.
