# Disposable PostgreSQL 17 reconciliation test

This package is an isolated SQL regression test. All identities, descriptions, timestamps, amounts and account references are invented. It has no production connection, personal source records, application deployment or merge step.

## Run model

The workflow runs only on a test branch whose name starts with `test/reconciliation-postgres17`. It creates an official PostgreSQL 17 service container and uses the client's own psql binary via `docker exec`, so no database client or Python dependency is installed on the runner. No database port is mapped to the host. The service's publicly known dummy password is only for this short-lived container. No custom GitHub secret, production credential, volume or persistent environment is used.

- Static-only: `python3 ci/reconciliation-postgres17/run_tests.py --static-check-only`
- Source privacy guard: `python3 ci/reconciliation-postgres17/scan_public.py`
- Runtime: the workflow supplies a container ID and `ALLOW_DISPOSABLE_RECONCILIATION_TEST=1` to run_tests.py. The runner does not accept a URL or remote database configuration.

The setup fails unless the database is named `reconciliation_ci` and the server major version is 17. It recreates only `reconciliation_fixture`, never public or another database. Each test begins from new fixtures.

## Parametrized transaction

apply.sql and rollback.sql contain the same reviewed transaction/control-flow pattern with fixture relations and a JSON contract injected through `reconciliation_test.contract`. Identity/value/date/definition hashes come from the synthetic contract. The default transaction ending is ROLLBACK; the test runner can change only that terminal token to COMMIT inside the disposable fixture.

Substitutions are limited to:

1. Relation/function/schema names mapped to fixture objects.
2. Exact identity/value/date/audit literals supplied by the fixture contract.
3. Runtime hashes read from the fixture definitions and rows.
4. A database/version/fixture-marker safety guard.
5. Three inert comments where the concurrency tests may inject advisory-lock barriers.

The substantive guards remain: READ COMMITTED, the link-table lock, target FOR UPDATE, source FOR SHARE, immediate validated operation FK, original JSON/hash leases, source stable/full-row leases, conflict checks, exact applied-state recognition, ROW_COUNT=1, automatic epoch/cache checks, and receipt-bound inverse.

The fixture readers are intentionally small and only prove suppression semantics. They are not copies of an application reader or a full financial UI. A passing job establishes SQL compilation and the tested invariants on invented data; it does not establish that a production correction was performed.

## Scope of runtime proof

The suite covers first apply, idempotent repeat with no new DML/sequence/cache effect, conflicts and stale leases, exact inverse and receipt tampering, empty/malformed target cases, controlled failure atomicity and real concurrent PostgreSQL sessions. Fixtures include an unrelated owner/event, a future expectation, a pending item and cache sentinels for two owners plus a null-owner row.

A dry-run ROLLBACK restores business rows, epoch and cache, while the allocated bigserial value remains consumed. Tests explicitly distinguish that sequence effect from a no-write second application.

Concurrent actor tests use barriers and PostgreSQL blocker evidence rather than fixed sleeps. They exercise operations before/after the target row lock, competing applications and the source's FOR SHARE lock. Observer queries coordinate the tests; they do not replace the two contending sessions.

## Evidence status

Only the CI run can establish that the PostgreSQL runtime cases passed. Preparing this package or passing static checks is not a runtime pass. Review the job's exit status, per-test logs and the reconciliation-postgres17-results JSON artifact before using it as evidence. The JSON contains case statuses and code hashes, never fixture row snapshots. The service is removed after the job; no production action follows success.

Workflow reference: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers
