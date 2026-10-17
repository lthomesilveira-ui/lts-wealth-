# Synthetic exact-obligation PostgreSQL17 gate

This directory is a deliberately isolated, synthetic-only allowlist. Every identity, amount, date, property and evidence string in fixture.py is invented. No production files, secrets, project URL or database hostname are inputs. There are no network, migration, push, deployment or publication calls.

Requirements: Python 3 and psql against a freshly created PostgreSQL 17 loopback database. Create a disposable superuser/database named wealth_synthetic_iptu with password synthetic-ci-only. The runner checks server major version, database/user identity, loopback target and an empty public schema before bootstrap; it refuses to run without --allow-fresh-synthetic-postgres17. Do not reuse this database for any real data.

Run: python run_postgres17.py --allow-fresh-synthetic-postgres17 --port 5432

The writer and inverse are rendered from the same generic templates as the private candidate. Only synthetic contract values and freshly measured fixture catalog/row hashes are supplied. The integration consumers here are explicit synthetic models, not certification of production reader definitions. Passing this suite does not authorize a production mutation or publication. Result JSON separates database tests from production verification.

The maintenance transaction is READ COMMITTED with bounded lock/statement timeouts. Lock order: audit, decisions, links; target event FOR UPDATE, protected events in UUID order; sources in UUID order FOR SHARE; account; epoch. Source administrative polling is admitted only for exact retries/inverses by excluding exactly sync_run_id, last_seen_at and updated_at. New material changes still abort.

The first apply changes one exact decision, inserts one exact link, and suppresses one forecast through only is_suppressed/suppression_reason/metadata. The previous event and postimages are retained in append-only audit. Retry writes nothing. Inverse requires separate authorization and a pinned committed audit hash, and does not rewind sequences or epochs. Later event/link/decision edits abort. No bank payment is executed.

The invalidator fixture mirrors the changed-detection and epoch-before-cache branch used by the three modified tables. It does not model unrelated observation/connection branches. The source-reuse concurrency claim covers cooperative writers using this lock protocol in the coordinator's serialized window. No unique source constraint is added; an arbitrary writer that ignores the protocol after COMMIT is outside this guarantee.
