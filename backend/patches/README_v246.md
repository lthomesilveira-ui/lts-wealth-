# V246 backend performance for the published V245 application

The application URL remains /releases/v245/app.html. V245 and earlier releases are immutable. This change modifies derived read behavior without changing money, event dates, classifications, resource policies or source evidence.

Apply the four patches in order:
1. semantic_rule_routing_v246.sql: retains the previous historical classifier privately; routes exact rules through the existing partial index and prepares the 25 prefix/contains patterns once. All precedence rules remain identical.
2. linear_history_rows_v246.sql: retains the previous three readers privately; accumulates daily JSON rows before final serialization.
3. finance_cache_invalidation_v246.sql: replaces 106 indiscriminate statement triggers with insert/update/delete transition triggers and truncate guards. Zero-row writes, unchanged bank ingestion bookkeeping and unrelated Health writes preserve finance caches. Actual source changes invalidate them. Repeated checking balance observations are ignored only when an earlier observation has exactly the same owner, connection, provider identity, hash and complete raw/normalized payloads. Other observation resources are not read by the finance cache's dependency graph.
4. flow_receipt_freshness_v246.sql: adds the bank receipt's 24-hour age boundary to the full-flow cache fingerprint and matching private background renewal.

All source amounts, dates, provider deletion flags, hashes, normalization, identity links, connection identity and permissions remain relevant to invalidation. No append-only financial guard or RLS policy is changed. Diagnostic mutations are confined to a BEGIN/ROLLBACK transaction.

Verification:
- backend/qa/lts_v246_cache_rollback.sql: live rollback checks for empty writes, bank ingestion bookkeeping, unrelated Health writes, financial/source changes and retained append-only restrictions.
- 4,620 historical source rows compared with the retained classifier: zero differences.
- All 730 displayed days and historical/current-future events compared before and after: exact equality.
- A paired derived-cache reconstruction measured 18.4047 s before and 11.7078 s after. These are server observations with existing underlying future-engine caches, not device or total-network times.
- The real next hourly sync completed for all three institutions without changing the finance epoch when source facts remained identical. Prepared two-year reads measured about 0.25 s.
- Full browser regression runs use the frozen V245 frontend. Private financial payloads and live evidence are kept outside this public repository.

Run node backend/qa/lts_v246_source_gate.js. The V246 workflow also runs the existing V245 period/disclosure, startup, historical, balance, cards, classification, inventory and expense suites. Device acceptance and further cold-reader optimization remain tracked separately.

