# V244 regression repair — 2026-10-04

Apply in order using the configured project migration workflow:

1. `read_only_memo_v244.sql`: four private memo helpers skip cache writes in read-only transactions. Cached reads and computed results remain available; no grants, sources or financial values change. A POST of a STABLE RPC is read-only in PostgREST. The previous V243 memo inserts made `lts_open_finance_sources_v226` fail with SQLSTATE 25006, blocking all three ingestion paths.
2. `historical_fgts_precedence_v244.sql`: historical FGTS uses the latest primary position whose `as_of_date` is no later than the displayed day. Existing current/future arithmetic is untouched. The receipt is an asset transfer; later primary positions replace estimates. Missing primary evidence preserves the original historical/unknown value. Bump the flow memo fingerprint, not the source facts.

The original V242 frontend and all earlier frozen evidence remain byte-identical. V244 copies the approved UI, makes full-year cold reads respect the 45-second database limit, retries a transient changed-source forecast once, clears recovered status-query errors, and restores a legible daily chart at phone width with exact-value inspection. The year selector and custom date range remain owned by the existing flow screen.

Verification includes authenticated normal-role production reads, complete future-array and historical non-FGTS equality before/after the FGTS correction, a read-only cold source query, successful configured ingestion for Itaú/Bradesco/C6, all 365 days of 2027, and browser gates at desktop/phone width including a 26-second full-year response. Financial amounts and private source evidence are kept outside GitHub. Provider freshness and actual posting availability are not equivalent to ingestion success. No provider record is fabricated or silently promoted to clear a discrepancy.

Still open: original source/document gaps, transaction identity/coverage, bank balance-versus-ledger reconciliation, D0 component confirmation, and the financial scenario's source-backed deficit. V244 is not an assertion that the complete project backlog is closed.
