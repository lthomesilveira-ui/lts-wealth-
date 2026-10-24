# V307 — Native historical Flow performance

The annual 2019 reader exceeded the authenticated 8-second statement budget
when its private memos were cold. This patch reduces repeated card composition,
classification work used only for date/amount aggregates, and intermediate JSON
reconstruction. It retains the native financial contracts and all read-boundary
checks.

## Changes

- Keep a separate private card-cycle snapshot next to the existing small
  completeness state. Share it between invoice composition and Flow.
- Invalidate against the existing financial epoch, every bank's receipt-only
  fields, invoices/documents, and untriggered settlement links/contracts.
- Read the first C6 date without computing unused classification columns.
  Preserve duplicate posted-evidence suppression, bank-effective dates, paid
  C6 recovery, fixed historical bounds, and the existing memo.
- Use the financial-equivalent V2 source for the daily reader's amount-only
  tail; skip the recent-anchor branch when none of its dates can join.
- Build four JSON arrays once, materialize intermediate balance patches, and
  reuse the already materialized document-match relation.

The migration leases seven dependency definitions and eleven target definitions.
It preserves existing OIDs, owners, ACLs, security mode, volatility and settings.
Its sole new helper is invoker-only and unavailable to anon/authenticated.
It creates no table and writes no financial/source/classification rows.

## Validation

- Real owner, SQL authenticated, both sides with cold private memos in the
  same repeatable-read transaction: the full 365-day 2019 response improved
  from **12,346.417 ms** to **5,907.684 ms**, under an **8s** candidate timeout.
  Complete response JSON checksums matched exactly.
- Five complete native-response comparisons passed: annual 2019, early 2013,
  first C6 activity, July anchors and recent October. All twenty source-table
  hashes and all existing function security/identity attributes stayed exact.
- The exact migration compiled and replayed transactionally with all twelve
  functions present and existing attributes preserved.
- `python3 backend/qa/lts_v307_live_rollback.py --case year` emits a complete
  native comparison with cold memos, authenticated role, the real 8s candidate
  timeout, checksums, source hashes and attribute checks. The other choices are
  `early`, `c6`, `anchor` and `recent`. Each transaction always rolls back.
- CI uses the actual source-epoch invalidation body and actual new memo/helper
  bodies, with an explicit card-cycle dependency double. It checks changes in
  other banks, receipt-only refreshes, settlement contracts without epoch
  triggers, owner partitions, malformed cache entries, null owners,
  insert/delete/truncate invalidation, private access and read-only fallback.
  Seventeen integrity assertions and two true read-only assertions passed.

The SQL timing is a database check; it does not certify private HTTP sessions,
other-owner HTTP isolation, physical devices or completion of historical source
reconciliation. No financial unknown or future forecast is marked paid.

