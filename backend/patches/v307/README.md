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

- Real owner, SQL authenticated, cold private memos: the full 365-day 2019
  response completed in **7,110.489 ms** with an **8s** statement timeout.
  Complete response JSON matched the original baseline exactly.
- Original whole-reader diagnostic baseline was about 11.6 seconds.
- The exact migration compiled and replayed transactionally with all twelve
  functions present and existing attributes preserved.
- `python3 backend/qa/lts_v307_live_rollback.py` emits optional complete native
  comparisons for early history, the first C6 period, July anchors and October.
  It includes source-table hashes and always rolls back. Run cases separately
  when the connected SQL transport cannot return a longer batch.
- CI uses the actual source-epoch invalidation body and actual new memo/helper
  bodies, with an explicit card-cycle dependency double. It checks changes in
  other banks, receipt-only refreshes, settlement contracts without epoch
  triggers, owner partitions, malformed cache entries, null owners,
  insert/delete/truncate invalidation, private access and read-only fallback.

The SQL timing is a database check; it does not certify private HTTP sessions,
other-owner HTTP isolation, physical devices or completion of historical source
reconciliation. No financial unknown or future forecast is marked paid.

