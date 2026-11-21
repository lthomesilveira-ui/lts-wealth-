# Temporal date overlay: synthetic PostgreSQL 17 gate

Status: prepared and tested offline in Python. PostgreSQL has not been executed.
This package contains only invented identities/dates/amounts. It has no connection,
credential, source receipt, customer data, financial production function, frontend,
DDL, DML or CI workflow. Sending this package does not authorize running it.

## What this proves after a successful PG17 run

The CTE/SELECT computes an overlay of one exact invoice revision onto one already
identified obligation/cycle. It returns complete JSON obligations and explicit
source/decision findings. The verifier compares every field and JSON type against
an independent, frozen expected result, then checks deep preservation, cardinality,
scope totals, daily redistribution and the declared synthetic D30 convention.

The 28 baseline cases are unchanged inputs: 29 obligations, 37 invoice rows and
exactly 10 changed due dates. They are replayed individually and as one combined
batch. Fifty-six additional regression cases cover gaps in the old gate; total 85.
The new reason for a preserved record may be more explicit; all baseline dates and
cardinalities remain identical. Expectations are explicit decisions in
build_cases.py. Neither SQL nor overlay_reference.py generates the oracle.

## Boundaries

This is an algorithm gate over supplied, independently verified bindings. It does
not build a real source adapter, certify a complete source snapshot, reconcile a
new obligation, propagate nominal due days, replace monetary reconciliation, or
execute any real financial consumer. A synthetic date is not evidence of any real
card's effective date. No UI/diagnostic package is used as financial correctness
proof. A successful run alone cannot authorize a product change.

No financial rows or bindings are persisted. The five allowlisted in-memory
changes are due, provenance, source_updated, bill_key, due_basis. The latter four
record the evidence already used by the overlay; they are not inferred mappings.
Every other field, including nested payloads and unknown fields, is preserved.
Blocked obligations are byte-independent JSON-tree-identical in their entirety.

Source identity is owner/institution/account/BillID. Family is a consistency label,
never sufficient to bind. The independent binding keeps cycle_id/reference_month
when due crosses a month/year. Reference months and cutoff must be YYYY-MM-01.
Received time is deliberately not parsed or used as issuer revision time.
Issuer timestamps require a timezone; malformed or unknown versions block the
whole BillID. Latest tombstones never revive an older active revision. Deletion
must be an explicit boolean. Conflicting equal-version source content blocks.
An official prior snapshot needs its prior exact BillID and known source version.

Claims are counted from scoped, independent bindings before source-head filtering.
A competing BillID that is absent, deleted, uncertain or ambiguously bound still
blocks the affected obligation. Duplicate identical bindings are idempotent.
Removing a stale claim requires a separate documented invalidation/substitution;
this gate never assumes that absence or deletion supplies that evidence.

Protected months, fulfilled/unknown status and linked payments remain unchanged,
even under conflict/deletion. Invalid obligation/binding/identity shapes preserve
the batch with an explicit invalid state. Invalid source revision/state retains
valid input obligations with per-source findings. A malformed outer fixture file
is a harness error, not a supported production reader payload.

Amounts are finite, nonnegative decimal strings with 1–18 integer digits and at
most two decimal digits. Invalid source amounts block; changed valid amounts are
outside the date-only scope. A null old due is retained in an explicit undated accounting bucket before an
overlay assigns its exact date; it cannot disappear from conserved totals.
Actual provider currency/warnings contracts belong
to the future adapter. D30 here means today < due <= today + 30 days, a declared
synthetic convention, not certification of a product window or balance formula.

## Offline checks (no database)

Run from this directory:

    python -m unittest -v test_package
    python run_pg17.py

The default runner only verifies the package manifest and every member hash. It
does not search for a database or invoke psql. Hash-checked file bytes are retained
in memory and those same snapshots feed SQL and verification, preventing a later
filesystem change from being attributed to the reviewed pin. Rebuilding deterministic fixtures
and SQL is covered by tests; it must not change reviewed hashes.

## Future authorized PG17 execution

An authorized operator must separately provide an already running, disposable,
local PostgreSQL 17 instance and dedicated database. This package does not install
software, start a cluster, create a database, change permissions, contact a remote
host, or accept an inherited connection. The operator must verify disposability;
a Unix socket and database name are safeguards, not independent proof of it.

With the externally reviewed PACKAGE_MANIFEST.json SHA256 and an unused result dir:

    python run_pg17.py --execute-local-pg17 --ack-disposable \
      --expected-manifest-sha256 REVIEWED_64_HEX_SHA256 \
      --socket-dir /tmp/OPERATOR_VERIFIED_DISPOSABLE_SOCKET \
      --port EXPLICIT_PORT --database overlay_pg17_test --user EXPLICIT_LOCAL_ROLE \
      --result-dir /tmp/NEW_SYNTHETIC_RESULT_DIRECTORY

No default host/database/user/port is accepted. /tmp Unix sockets only, password
prompt disabled, inherited libpq environment removed, no service/password files,
psql startup files disabled. It checks PG17/socket/read-only in the execution session before evaluating the algorithm; its metadata is emitted
by that same session. The transaction is
READ ONLY with fixed UTC/ISO parsing, pg_catalog search path, bounded timeouts and
ROLLBACK. All SQL is a CTE/SELECT over literal synthetic JSON.

Failure, timeout, wrong server, missing/extra/duplicate results, non-boolean flags,
NULLs, changed amounts, missing fields or any exact-result mismatch returns nonzero.
Only a verified run writes actual.json, stderr.txt and receipt.json in the new
result directory. The receipt marks pg_executed=true and pins package/server checks.
No receipt exists in this prepared package. Never replace a missing PG receipt with
an offline Python result or describe this as a full consumer integration test.

## Files and dependencies

- baseline-28.json: unchanged prior synthetic fixture, including its old due oracle
- build_cases.py: explicit 85-case construction and oracle decisions
- inputs.json, expected.json, case-catalog.json: frozen inputs, full oracle, inventory
- overlay_reference.py: standalone Python reference, no database/I/O
- build_sql.py, overlay_contract.sql: deterministic complete CTE/SELECT, no helpers
- verify_results.py: exact typed verifier and independent preservation checks
- run_pg17.py: explicit future PG17 runner, offline by default
- test_package.py: offline contract and verifier/runner counterexamples
- PACKAGE_MANIFEST.json: allowlisted member hashes; must be externally pinned

Runtime dependencies: Python 3.12 standard library; an operator-supplied official
psql client and authorized disposable PostgreSQL 17 for the later database gate.
No SQL ancestors or extensions are omitted: the algorithm uses pg_catalog builtins
only. Real Wealth ancestors/consumers are outside this package by construction.

Official syntax references, consulted during preparation:
- https://www.postgresql.org/docs/17/functions-info.html#FUNCTIONS-INFO-VALIDITY
  pg_input_is_valid is used inside guarded casts, not a regex-only safety claim.
- https://www.postgresql.org/docs/17/app-psql.html
  psql startup suppression, ON_ERROR_STOP and conditional same-session gate.
