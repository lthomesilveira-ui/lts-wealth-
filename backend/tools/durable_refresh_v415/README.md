# V415 backend gate

These checks apply the exact reviewed V415 migration to isolated synthetic databases. Ten guarded predecessor definitions are installed with their exact function bodies; the original seven execution boundaries retain their captured owner, ACL, volatility, security and execution settings. The browser predecessor also matches the repository's immutable V357 patch. No predecessor hash is relaxed for tests.

Only after the migration has passed its guards do deterministic synthetic v2/v5 cache builders replace the expensive dependency bodies. They retain the production call contract and simulate complete payloads, the v5 canonical short circuit, row locks, partial writes, failures and cancellation. The real V307 completeness memo function and V269 product/flow presentation guards remain installed; only the cold card-cycle dependency is synthetic. Source rows are synthetic and fingerprinted before and after the checks.

## Run

```sh
python3 backend/tools/durable_refresh_v415/test_sql.py > /tmp/v415-core.sql
createdb v415_core
psql -X -d v415_core -v ON_ERROR_STOP=1 -f /tmp/v415-core.sql

python3 backend/tools/durable_refresh_v415/test_sql.py --setup-only > /tmp/v415-native-setup.sql
createdb v415_concurrency
psql -X -d v415_concurrency -v ON_ERROR_STOP=1 -f /tmp/v415-native-setup.sql
python3 backend/tools/durable_refresh_v415/concurrency_test.py --database v415_concurrency --output /tmp/v415-concurrency.json
```

The SQL-only gate also runs on PGlite/PostgreSQL17.5 for rapid feedback. That runtime does **not** certify multi-session locking. The targeted GitHub workflow uses native PostgreSQL17 for both gates.

## Native concurrency scope

The worker commits its claim before beginning the heavy transaction, in one persistent connection. A separate advisory barrier pauses the synthetic operational builder after it owns both the product row and a lower memo row. Independent sessions then check:

- Invalidation advances the request and source epoch without waiting on either cache row. The superseded worker rolls back all cache changes; the next worker publishes the new version.
- Repeated public request/status calls coalesce. A second scheduler does not steal the live lease, and a duplicate worker cannot enter the heavy section.
- An independently committed epoch change prevents publication even without a new request version.
- A receipt-only change with an unchanged global epoch also prevents publication through the independently checked V307 fingerprint. All newly written card memos roll back with the product.
- Terminating the synthetic worker connection rolls back its cache changes while preserving its committed claim and attempt. Expired leases consume the bounded retry budget.

The `cron` table/API are small fixtures. Tests verify the generated two-transaction commands, unchanged daily identity/schedule and untouched unrelated jobs; they do not certify live pg_cron execution. These checks also do not benchmark the real full product computation or certify the user's private browser session. Those remain explicit deployment checks.
