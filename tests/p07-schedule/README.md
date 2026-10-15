# Synthetic schedule transaction QA

Review package only. No database execution or successful PostgreSQL CI run is claimed by these files. The offline checks can run without network or a database. The PostgreSQL suite must pass on the final reviewed candidate before this package is called tested.

## Scope and privacy

This package exercises the frozen schedule-extension and suppression-recovery DO blocks for the financial-events and legacy-replacement-rule slice. It is not coverage of an entire product change, a live deployment, or the complete reader graph. A separate documentary gate exercises the reviewed public reader and actual renderer contract using independent synthetic tables and fixtures; it is not a browser test.

In the financial suite, all 36 existing events, 24 new events, 12 legacy projections, UUIDs, descriptions, contract identities, dates, amounts, bank names, document names, source labels, document fingerprints and evidence are synthetic. The separate documentary fixtures also use synthetic financial data. Fixed product identifiers from the reviewed public code, including the short label in its guardrail and minimum API selections in its tests, are preserved by file and exact SHA-256 in `public-source-exceptions.json`. This narrow exception does not cover private values, UUIDs, contract numbers, source labels or document names. The synthetic amounts are an intentionally simple integer sequence; they do not reproduce a real amortization table. The original private generator, records, receipts and document are excluded.

The DO blocks were mechanically extracted from a reviewed private candidate. `source-contract.json` fingerprints only the synthetic logic and generic code included in this package. Full linkage to the private originals is retained exclusively in a separate private review receipt. Only embedded JSON fixtures and allowlisted data literals in guards were replaced. Operators, comparison shapes, counts, locking, isolation, catalog guards, exception branches, writes and postconditions were retained. A private extraction tool performs a source-to-synthetic structural equality check and derives its private-identifier leak scan from the source. That tool must not be published. Changes to the source require renewed extraction, review, checksums and tests.

The two leased functions, owner resolution and cache invalidation, are included byte-for-byte. Their original expected MD5 values are unchanged. No production connection string, credentials, secret, source records or API calls are used. The standard names `public` and `auth` are retained in an entirely new disposable database; there is no schema-name or hash substitution to weaken a guard.

## Files

- `apply.review.sql`, `recovery.review.sql`: real candidate logic with synthetic declarations; each standalone review wrapper ends in ROLLBACK
- `fixtures.json`: independent synthetic data, including full existing-row and rule backups
- `schema.sql`: minimal compatible tables, keys and foreign keys
- `owner.sql`, `cache-trigger.sql`: exact leased helper definitions
- `block-delete.sql`: exact generic append-only deletion guard, also fingerprinted by the suite
- `structural-contract.json`: seven exact catalog constraints and nine exact catalog triggers
- `legacy-suppression-predicate.sql`: exact relevant NOT EXISTS clause extracted from the saved reader definition
- `connection_config.py`: explicit loopback address, no DNS or libpq service configuration
- `test_static.py`: offline integrity, synthetic identity and fixture checks
- `test_postgres.py`: 38 PostgreSQL 16 financial integration and concurrency tests
- `documentary_*`: separate reader/renderer gate, with five offline and six PostgreSQL tests
- `public-source-exceptions.json`: bounded public product-identifier exceptions, pinned per file
- `.github/workflows/p07-postgres16.yml`: isolated CI service, no repository or production secrets

The financial-events DELETE trigger and its generic `block_delete()` function are also preserved exactly. The candidate does not contain a hash lease for that third helper; the test package adds a fixture-integrity check without changing the candidate. No helper is stubbed. Auth identity tables are minimal local fixtures; RLS, grants, extensions, real auth services, all table columns not present in these guarded rows, and unrelated trigger branches are not modeled. This is transaction-contract QA, not proof of live schema or authorization equivalence.

## Verification

Offline:

    python test_static.py
    python documentary_position_gate.py
    python -m py_compile test_static.py test_postgres.py documentary_position_gate.py

PostgreSQL 16, only with a disposable local service:

    python -m pip install -r requirements.txt
    P07_QA_ALLOW_DISPOSABLE=1 PGHOST=127.0.0.1 PGPORT=5432 \
      PGUSER=postgres PGPASSWORD=qa-only python test_postgres.py

The suite refuses non-loopback hosts, libpq service configuration and other PostgreSQL major versions. It passes an explicit loopback `hostaddr`, overriding ambient `PGHOSTADDR`, and disables TLS/GSS for this local-only throwaway service. It ignores application DSNs, generates its own `p07_qa_` database name, creates that database, and drops only that same generated database in cleanup. Never point a test command at a live database or forward a production database to the allowed loopback port. The `qa-only` password is exclusively the disposable CI container's throwaway credential.

To integrate after explicit publication approval, copy only this package's manifest-listed files and `package-checksums.json` (excluding `.github/`, `__pycache__/` and generated logs) to `tests/p07-schedule/` and its workflow to the repository's `.github/workflows/`. Keep the package's local checksums unchanged. No PR or push has been made by preparing this package.

## Behavioral coverage

The PostgreSQL suite checks:

1. Exact fixture schema, helper hashes and catalog guards allow the happy path.
2. Apply inserts exactly 24 rows, preserves 36 backups and the legacy ledger, changes the exact rule including applied timestamp, and invalidates cache exactly twice.
3. Repeated apply is an exact no-op, including cache epoch and cached rows.
4. Standalone review wrappers roll back; a forced transaction failure after all writes rolls back events, rule and cache atomically.
5. Partial state, duplicate IDs/legacy identities, extra contract identities, altered values/metadata/backups/rule timestamps/legacy manifest and account binding abort without additional mutation.
6. Missing/ambiguous owner, changed owner/cache function definitions, disabled/extra trigger, added constraint and changed relation kind fail closed.
7. Recovery suppresses only the exact 24 new identities, preserves unrelated and other-user rows and all 36 old backups, restores the complete old rule, and never deletes financial events.
8. Repeated recovery is an exact no-op; reapply after recovery does not silently reactivate rows.
9. A real two-connection race holds an edited new-row lock while recovery begins. Recovery must reach that lock, then abort with SQLSTATE 40001 after the writer commits. It must not overwrite the edit or restore the rule. The final changed state also fails the explicit recovery guard.
10. Legacy visibility uses the saved reader's exact suppression predicate, without installing or calling the historical reader. It checks before/apply/recovery, active flag, owner, source table, description, account, inclusive dates and null wildcards.
11. The real cache trigger does not invalidate on zero-row or unchanged updates, and the deletion guard rejects deletes.

The frozen candidate remains review-only. A passing synthetic suite cannot attest to documentary provenance, a fresh production backup, UI completeness, or production authorization.

## Separate documentary gate

The six `documentary_*` files preserve the exact reviewed reader definitions and the exact public `docFinDetail` renderer. Offline checks compare the source delta, fixed hashes, schema constraints, explicit time-zone boundary calculations and first-match/fallback rendering. PostgreSQL tests compare original and candidate results, latest eligible positions, boolean-only TR notes without duplication, owner isolation, future-only and empty cases, constraints and the extracted local-day expression at explicit boundary instants. They check that both data tables stay unchanged.

The workflow uses separate financial and documentary jobs, each with its own PostgreSQL 16 service and log. With Node 22 and the repository's real release HTML available, the documentary job runs:

    python documentary_position_gate.py --postgres --ui-source ../../releases/v271/index.html

This uses its own newly generated disposable database through the same loopback-only connection configuration. The HTML path is relative to `tests/p07-schedule/`. The renderer hash must match the actual repository function; a generic recreated renderer is not accepted. The standalone default gate is offline and uses the frozen public renderer, while `--ui-source` additionally verifies the actual release source. PostgreSQL execution and browser behavior are never inferred from offline success.
