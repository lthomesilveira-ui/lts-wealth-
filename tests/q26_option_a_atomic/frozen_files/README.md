# Disposable PostgreSQL 17 atomic-control gate

Status: prepared locally, not executed, not authorized for export by this file. The consumer integration suite is an independent prerequisite; no success is inferred from its existence.

## Run only after independent review

Use a fresh PG17 container and an initially empty database named `fixture_option_a_atomic_<suffix>`. Set `OPTION_A_SYNTHETIC_DISPOSABLE=YES`, `PGHOST=127.0.0.1` (or `localhost`), explicit `PGPORT`, `PGDATABASE`, and `PGUSER`. The admin connection must be able to create disposable roles. Do not pass PGHOSTADDR, PGSERVICE, PGSERVICEFILE, PGSYSCONFDIR, PGOPTIONS, database URLs or service credentials. Run `python3 run_disposable.py` from this directory. The runner verifies its allowlist hashes before connecting. It never uploads artifacts.

Expected: exactly the labels in EXPECTED_RESULTS.json, currently 175 functional results and 10 concurrency results. Functional failures each produce two independent assertions: rejection and complete state preservation, including the later legitimate edit made outside the catching subtransaction. Sequence consumption is deliberately excluded from state equality.

## What is executed

The setup copies the sanitized, frozen complete bodies of both consumers and their declared ancestor stubs. The transactional gate executes the same apply and rollback DO controls under the bindings in ALLOWED_TRANSFORMATIONS.json. It compiles original/candidate bodies, calculates the synthetic immutable pin in PostgreSQL, captures canonical function contracts, and requires exact before/after contracts. Functional execution is one transaction that ends in ROLLBACK and verifies no remaining fixture objects/roles.

The concurrency gate then commits only the disposable fixture setup. Independent sessions prove both writer orderings, protection of a receipt while rollback waits for the epoch, and expiry after evidence/epoch lock waits. Finally the runner removes only the disposable schemas and roles it created and records cleanup. This committed disposable setup is necessary for cross-session visibility; it is not a production migration.

Functional coverage: exact apply, +2 epoch changes through the existing trigger body, global cache invalidation for every non-null owner, exact zero-DML repetition, partial/conflicting states rejected, catalog/source/classification/audit CAS, final injected failure in apply and rollback, revocation with immutable evidence retained, restore both original functions, delete only the inserted decision, append compensation receipt, and exact zero-DML compensation repetition. Revoked operations cannot be reapplied. Expiry covers absent/null/types/parse/nonfinite/past and boundary checks.

Consumer readbacks inside this gate compare the complete synthetic detail from 114 to 113 items, preserving the 112 non-targets, unchanged core and November, and exact full original output after compensation. The separate consumer suite has wider malformed-runtime/role coverage. Ancestor stubs, plumbing grants and fixture tables are not proof of the entire production dependency chain. ACL claims are confined to the unchanged two consumer contracts and the modeled existing evidence/audit contracts. No production permission is granted by this fixture.

## Technical effects and limits

The production control proposes only replacement of two existing functions, insertion of one existing-table evidence row and one representative decision, and a minimal receipt in the existing audit table. Compensation restores those functions, revokes evidence state, removes only that decision, and appends one receipt. No persistent helper, schema, table, index, grant or policy is introduced.

The evidence SHARE ROW EXCLUSIVE lock briefly blocks evidence writers for every owner because the existing table has no logical pair uniqueness constraint. Exact source rows, prior classification and existing operation receipts are locked in deterministic order; global epoch is acquired last. The existing trigger increments epoch for each changed evidence/decision statement and invalidates all non-null-user cache entries. Audit has no invalidation trigger. Apply and compensation each cause exactly +2; idempotent checks cause zero.

A different-ID conflicting contract may be inserted after commit. The runtime then returns the original consumer output. No persistent review marker or automatic alert is promised. The gate tests this conservative fallback. A 2-second lock timeout bounds lock waits; the 2-second elapsed check can only abort after work finishes. No remote statement timer or hard runtime ceiling is proved. The runner has its own disposable-test timeout, which is not deployment evidence.

Catalog signatures/contracts in this gate cover the two consumers, their available synthetic ancestors, the real invalidation body and seven required tables. They are deliberately not the production 104-function lease. Missing production pin, fresh contracts/data, exact audit identity metadata, canonical compiled hashes, policy review and release authorization remain held outside this public package. No production identities, private maps, financial snapshots, authorization transcripts or lease bindings are exported.

Locks remain held until the surrounding transaction commits; the DO elapsed check does not bound time after DO return. Audit sequence values consumed by an aborted INSERT are not restored. The compiled-definitions export contains each reviewed DDL input and its compiled catalog contract/hash; it is not a textual pg_get_functiondef reconstruction. Generic institution names/codes in the preapproved CASE mapping remain unchanged; no nominal source identity is admitted by that narrow code exception.

Before setup, four independent transaction-scoped guard tests prove rejection of a preexisting standalone function, sequence, enum and domain. The setup guard checks all pg_depend namespace dependents plus every pg_class relkind, pg_proc, pg_type and pg_extension entry in public. The guard tests roll back their own objects on the expected error and precede any disposable role creation or cleanup. They are reported separately from the unchanged 175 functional and 10 concurrent results.

The successful result.json is emitted only after exact cleanup equality: zero public relations of every kind, zero functions, types and namespace dependents, no auth schema and no fixture roles. Cleanup failure raises an error and never produces a green result receipt.

Revision 0416 additionally requires evidence metadata to be an object with exactly contract, immutable_fingerprint and state before INSERT. Extra/null/array metadata, non-boolean active and altered contract are rejected with full state-preservation assertions. The runtime is unchanged.
