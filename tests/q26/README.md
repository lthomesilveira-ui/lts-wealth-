# Q26 synthetic envelope gate

Prepared only. Not executed or published. All financial/user fixture values are invented. These tests do not validate the production reader chain.

Run only on a new disposable PostgreSQL17 cluster, with a dedicated superuser and database named wealth_synthetic_q26, password synthetic-ci-only, on loopback. The runner refuses any nonempty public schema, wrong database/user, non-superuser or non-17 version. It does not create or reset a real account or database.

Command: python3 run_postgres17.py --allow-fresh-synthetic-postgres17 --port 5432

The runner verifies generated file hashes, measures seven synthetic function leases, uses the current fixture-local date for the dated guard, runs the actual Q26 DO envelopes with entirely synthetic constants, and saves results/result.json only on success. The final receipt includes candidate hashes and template hashes. Failures are printed and exit nonzero.

The synthetic reader, installment-key function and cache trigger are stand-ins. The production candidate remains blocked; synthetic success cannot authorize production. Keep this gate separate from the five-overlay gate, marker, P05 and registry work.

## Timestamp regression guard

The live origin decision and historical audit fixtures use 2000-07-01T00:00:00-03:00. The runner first proves on PostgreSQL that 2000-01-01T00:00:00-03:00 serializes in America/Sao_Paulo as 2000-01-01T01:00:00-02:00 because of historical daylight saving, whereas July round-trips exactly at -03. It then compares the complete to_jsonb rows of all three origin decisions and both origin audits to their fixture expectations. Exact decision/audit guards remain unchanged. The old January literal exists only in this explicit counterexample.

The expected runner total is 25 cases. After the run, inspect results/result.json for status passed, database_tests_executed true, production_validated false and the matching template/candidate hashes. A passing fixture gate still requires independent review before any production decision.

For the integrator: provision a fresh PostgreSQL17 service configured with POSTGRES_DB=wealth_synthetic_q26, POSTGRES_USER=wealth_synthetic_q26 and POSTGRES_PASSWORD=synthetic-ci-only. Install a PostgreSQL client in the isolated runner. Copy exactly the 10 paths in PUBLIC_FILES.json while preserving generated/. Run the command above from this directory and retain the result plus process logs. Do not load private production candidates or connect to Supabase. No publication permission is granted by this package.
