# V243 backend performance repair for the published V242 application

No frontend release is changed: /releases/v242/app.html remains the application link.
No source money, event date, classification, FGTS policy or award assumption is changed.

Apply in order:
1. checking_observation_index_v243.sql — small partial owner/connection index for checking balance observations. Original observations and RLS are retained.
2. historical_cash_memo_v243.sql — exact original engine retained privately; epoch/day/owner/range-keyed row memo, five-minute limit.
3. flow_source_key_memo_v243.sql — retains original hash engine and verifies the bank receipt age boundary in addition to epoch/day/owner.
4. historical_cash_cover_v243.sql — only reuses a historical superset with exactly the same upper date; retains row order, strict date filtering and private grants. JIT is disabled on the authenticated flow reader only, not on the database.
5. repeated_sources_memo_v243.sql — exact-argument private payroll and invoice source reads, invalidated by the existing complete source epoch.
6. linear_bank_carry_v243.sql — preserves all future per-bank arithmetic checks while assembling the original daily rows linearly.

All new engines are private; original helpers retain service-role/postgres access only. No RLS policy is opened. An epoch change rejects an in-flight read with 40001. The existing writer clears derived read caches and future engine caches; retry idempotency remains unchanged.

Verification uses live source reads and rollback-only edits separately from synthetic browser fixtures. Cold tests clear both derived read caches and the underlying future cache in a transaction that is rolled back; warm timings are labelled separately. Financial day/event equivalence and exact source row equivalence are required. Unknown historical/current movements are not converted to zero. Private financial evidence is retained externally, never in this public repository.

Run: node backend/qa/lts_v243_source_gate.js. Browser regressions: .github/workflows/v243.yml, using the frozen V242 application.
