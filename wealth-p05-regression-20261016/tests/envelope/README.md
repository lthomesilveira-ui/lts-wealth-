# PostgreSQL 17 synthetic migration envelope

Status: prepared for a future run. No SQL has been executed by this preparation task. Static checks are Python compilation, deterministic fixture generation, artifact hashes, statement ordering, and SQL quote/delimiter/parenthesis checks. They do not replace PostgreSQL parsing or execution.

## What is tested

The generated apply/recovery DO bodies preserve the reviewed installer statement ordering and guards. They contain entirely invented user/payment/invoice/item IDs, contracts, links, sources, leases, and a 3-item / 60-unit consumer expectation. Baseline and candidate guard function bodies are included exactly. The reader and exclusion functions are synthetic test doubles, so this suite tests the migration envelope, not production reader integration. The separate pure-guard suite exercises the actual guard's semantics.

The proposed runtime gate checks:

- Numeric table OID equals its scalar catalog value; a string with identical digits is rejected without mutation
- Apply, exact candidate contract/body/ACL/OID, one epoch increment, and idempotent retry
- Recovery, exact original contract/body/ACL/OID, one epoch increment, and retry
- Post-DDL rejection restores the exact pre-attempt snapshot for coverage, final consumer, unrelated rows, NULL source rows, installed body hash, and documentary evidence failures
- Contract, guard ACL/OID, dependency ACL/body, table ACL/RLS metadata changes block changes
- Another active contract using the new policy prevents reverting the global guard
- Recovery failures are atomic and can be retried after the fixture issue is repaired

All snapshots include the entire synthetic contract set, function definitions/OIDs/ACLs/owners, table metadata, epoch, staging rows, and documentary rows. The source row with NULL table/reference is intentionally included in the before/after digest assertion.

## Publication boundary

PUBLIC_FILES.json is the exact public allowlist. Publish only those files, preserving their relative paths. The local build_envelope.py helper is intentionally excluded because it reads the private migration source and includes literal parameterization inputs. Never upload the private migration directory, builder, real contracts, leases, receipts, or private apply/rollback SQL.

The generated SQL has explicit non-operational lease placeholders. It must not be executed directly. run_envelope_postgres17.py measures only its newly created synthetic catalog and substitutes whole placeholder literals, including OIDs and table metadata. It never loads build_migration.py or private inputs. The source-builder SHA256 in the manifest is a provenance check, not a proof of production compatibility.

## Proposed execution

Use a fresh isolated postgres:17 service, database and superuser lts_p05_synthetic, password synthetic-ci-only. This hardcoded synthetic-only connection uses 127.0.0.1 and drops inherited PG environment settings. The preflight rejects non-17 servers, wrong identities, existing public objects/functions, or existing fixture roles. The service must be thrown away afterward; the runner leaves only invented fixtures for inspection.

From this directory:

    python validate_static.py
    python run_envelope_postgres17.py --allow-fresh-synthetic-postgres17 --port 5432

See postgres17-envelope.proposed.yml for a separate fresh-service CI job. Do not reuse a cluster already modified by another envelope run. The pure suite can run in its own job.

The runner creates the standard synthetic roles in the disposable cluster; functions/tables are owned by the postgres fixture role, while the configured disposable superuser executes the migration. No real credentials, remote hosts, or configurable production URLs are accepted.

## Local-only regeneration

The private build_envelope.py helper verifies a pinned builder and pinned baseline/candidate definitions before generating. It copies the builder to a new temporary directory populated exclusively with invented inputs, then runs that copy. Only three source literals are parameterized: two hardcoded reader digests and the expected consumer count/net. The builder must still have the same hash after generation. A changed source hash requires review and regeneration, never a blind pin update.

Regenerate only inside the authorized private workspace:

    python build_envelope.py --out-dir generated

Then run validate_static.py and independently scan the public allowlist for real IDs, source references, account/provider names, document evidence, and private amounts before upload. Local preparation does not authorize executing a database or publishing artifacts.
