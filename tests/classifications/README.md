# PostgreSQL 17 gate: exact classifications and generic marker

Status: prepared locally; PostgreSQL not executed here. No production SQL was applied and no files were published. Only paths listed by PUBLIC_FILES.json are eligible for review/publication; never copy the parent directory wholesale.

## Runtime

The proposed workflow starts a fresh, disposable postgres:17 service. The only accepted connection is 127.0.0.1, database and superuser `wealth_synthetic_classifications`, using the synthetic CI-only password. The runner builds a clean environment rather than inheriting PGHOST, PGSERVICE, DATABASE_URL or user credentials. Preflight refuses a populated public schema, the wrong database/role/version, or missing explicit opt-in. No production services or secrets are needed. The CI service must be destroyed after the job.

Run:

    python tests/classifications/validate_static.py
    python tests/classifications/run_postgres17.py --allow-fresh-synthetic-postgres17

The command paths assume only the allowlisted package was copied to `tests/classifications`. Adjust that prefix in the proposed workflow if needed. The proposal is not installed or enabled by this package.

## Envelope fidelity

The synthetic apply and rollback are parameterizations of the revised real DO envelopes, not Python simulations. The entire target payload, owner and operation identifiers, scope/expiry dates and function-MD5 lease literals are replaced with invented fixtures. The runtime measures leases on the disposable database and replaces only the complete placeholder literals. Private generators and real candidate SQL remain outside the allowlist.

The fixture tables expose the contract columns consumed by those DO blocks. Readers and installment-key lookup are deliberately declared stand-ins: this gate verifies PL/pgSQL envelope compilation, real SQL null/equality behavior, locks, statement triggers, atomicity, snapshots and invariants. It does not establish production classification semantics, production schema/ACL compatibility, authorization, or full upstream reader integration. The actual observed cache invalidation trigger body is executed against the synthetic review-decision table.

The separate marker suite executes the real final projection, with three replacements of property literals and one declared subgroup stub. See marker/README.md for its complete scope.

## Expected runtime coverage

- Exactly five overlays and one receipt; unchanged financial source rows
- Atomic apply and rollback, including failures after insert/delete
- Source hash, card metadata with unchanged hash, original decision and before-image drift
- Same installment key appearing on a future source outside the report window
- Output outside the five-source set, including NULL source identities
- Financial amount and raw-reference mutation
- Trigger-induced source, origin and hidden unrelated-decision writes
- Lease or cache-trigger binding drift
- Known global nonnull-user read-cache invalidation; one epoch advance per write statement; optional reader warming
- Idempotent refusal of repeated apply/rollback, without second effects
- Rollback refusal after a later decision or changed target output
- Two real PostgreSQL sessions: the second waits on a database lock, then refuses duplicate application
- Marker SQL NULL semantics, Education and all other review reasons preserved, all 19 other output fields invariant

A passed receipt is written only after every stage succeeds. Errors preserve completed-case details and report `status=failed`. Static checks expressly report SQL not executed; they are not a substitute for PostgreSQL. Production readback remains an independent gate after any separately authorized deployment.
