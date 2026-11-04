# V405: keep market refresh working after a database restart

The market request ledger used the `pg_net` request ID as a permanent primary key. The extension's request sequence is unlogged and may reset after an unclean shutdown. Reusing an old ID then aborted the new request transaction, so the hourly job stopped updating OGN and USD/BRL references.

This patch preserves every request and quotation. It adds `request_generation`, records `pg_postmaster_start_time()` on new requests and makes `(request_generation, request_id)` the primary key. The exact generation of older history was never captured: those rows receive the explicit unknown marker `-infinity`, except requests already created during the current server generation. No original column is changed by the migration.

The collector accepts a response only for the current generation and only when its response timestamp is at or after the recorded enqueue time. It updates the exact request pair. Pending requests from a previous generation are retained with an interruption result; they cannot consume a response for a recycled ID. A late failure of an older attempt cannot replace the status of a newer attempt. The quote parser, immutable quote observations, source URLs, head selection rules, cache revision semantics and hourly schedules remain unchanged.

`market_request_generations.sql` and its CLI-generated migration contain the same transaction-ready SQL. Apply it atomically after validation. It has bounded lock/statement deadlines, verifies the inspected predecessor function bodies and primary key, rejects foreign-key consumers that were not inspected, and supports replay. The request table retains RLS and the two workers retain service-role-only execution. Do not restore the old scalar primary key after distinct generations have reused IDs; a correction must preserve the composite identity and all rows.

## Validation

`backend/tools/market_request_v405/setup.py` builds an isolated fixture directly from the V290 worker and parser definitions already published in this repository, synthetic quote data and a network-free transport. No production function export or private source snapshot is included. `verify.sql` covers the original failure, generation and time binding, both sources, history preservation, HTTP/parse/timeout failures, latest-attempt status and permissions. `local_verify.mjs` also checks exact replay and atomic rejection of a changed predecessor on PostgreSQL 17.

The `v405-market-requests.yml` workflow runs the suite on native PostgreSQL 17. Its separately guarded `native_crash.py` test kills only the dedicated synthetic CI service, observes the actual unlogged-sequence reset, preserves the durable ledger and verifies fresh response collection after ID reuse. The local WASM test must not be described as that native crash test.

Production validation must separately confirm the deployed schema and worker bodies, preservation of the previous request/quote rows, and a successful real collection. These references affect valuation assumptions; the patch does not change financial events, bank movements or account balances.

References:

- [Supabase pg_net documentation](https://supabase.com/docs/guides/database/extensions/pg_net): asynchronous requests and unlogged request/response storage.
- [PostgreSQL 17 CREATE SEQUENCE](https://www.postgresql.org/docs/17/sql-createsequence.html): unlogged sequence behavior after a crash.
