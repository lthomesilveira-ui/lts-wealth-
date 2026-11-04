# V406: assemble the existing backup once

The modern exporter passes a complete backup through several wrappers and materialized intermediate results. That repeats work and retains full financial payloads during assembly. This change reduces that work while preserving the existing backup contract.

The previous modern exporter assembled the complete 31-table payload, copied it to add the family inputs, materialized that 33-table payload, then copied it again to add the two source-evidence datasets. It also merged complete JSON rows to choose referenced synchronization runs.

`single_assembly_export.sql` replaces that chain with one assembly of the same 35 datasets. Intermediate cohort relations retain only observation and run IDs. Financial arrays keep their original owner filters, column shapes and ordering; referenced runs are selected from the same union of source identities. The daily position/cohort selection and the V402 Cofrinho reader retain their existing logic.

Schema metadata requires two lookup contexts: PostgreSQL deparses sequence defaults relative to `search_path`. The small `lts_backup_base_schema_v406()` helper preserves the original 31-table metadata context; the four later datasets retain the other original context. The helper is `STABLE`, `SECURITY INVOKER`, has a fixed search path and denies execution to `PUBLIC`, `anon` and `authenticated`. Only `service_role` receives an explicit execute grant. The existing exporter's grants remain unchanged.

The migration checks exact bodies of the existing exporter and all three inlined predecessor helpers. It accepts replay of this exact V406 body and rejects other drift. Apply it atomically; the migration uses a five-second lock timeout and a thirty-second statement timeout for that deployment transaction. It does not run a capture, change any stored snapshot, edit a financial source, modify a schedule, replace the legacy exporter, relax the manifest, or alter the V403 exclusion locks. `rollback.sql` restores the exact V403 exporter and leaves the unused private metadata helper in place.

## Validation

The native PostgreSQL 17 workflow installs the real V380 → V403 pipeline with synthetic sources, then verifies:

- Exact complete JSON equality for six owners, an unknown owner and a null owner, including metadata and array order. Both exporter calls share one SQL statement timestamp.
- Sequence-default metadata in both schema lookup contexts.
- Unchanged exporter access, other backup functions and every existing schedule.
- The existing 18 V403 contracts for capture/read, original archives, historical profiles, source conservation, manifests and complete daily Cofrinho cohorts.
- Rejection of drift in each of five protected function bodies, plus exact replay and rollback.

Private fixture and resource measurements are kept outside the repository. No private source rows, live catalog exports, raw profile reports or authentication data are committed. Local resource measurements do not certify production latency, host memory, total-backup resource use or elimination of a service restart. The next natural scheduled backup must be observed separately before the remaining reliability item is closed.

## Verification after application

Confirm the installed function bodies and private helper ACLs; check scoped Supabase security advisories. Do not create another production backup just to test the exporter. Observe the existing next scheduled attempt, retries, server uptime and stored snapshot integrity. Record success or failure honestly and retain all previous backups.
