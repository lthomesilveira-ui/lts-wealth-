# V251 expense reader memo
The yearly Despesas RPC recalculated an identical report in about 11 seconds on
both first and repeat reads. The wrapper now reuses only exact owner, business-day,
period and source-epoch matches. The original calculator is snapshotted privately
without changing economics, dates, labels, amount signs or response version.
Every request still validates the authenticated user and inclusive range before
reading cache. Existing source transition triggers invalidate financial changes.
Read-only transactions calculate locally and skip memo writes.

Operator transactional probes compare complete JSON for current-year, current-
month/invalidation and an older year. They check an adjacent-period cache marker,
authentication, invalid ranges, private engine permissions and actual source
epoch invalidation. Fixtures, candidate DDL and cache writes roll back; all public
function definitions and ACLs restore. Only an externally inaccessible private
receipt persists. A foreign-owner cache test runs only when another existing auth
user is available; the pilot had none, so that check is explicitly not run.

First reads remain slow; warm memo speed is not cold performance or authenticated
phone acceptance. Future optimization should examine the baseline expense row
calculator (about 9.5 of the 11.3 seconds in the observed plan). Do not change
financial facts or source eligibility just to accelerate it. No new cron, UI,
credential, protection override or source deletion is introduced.

Build a probe from the repository root with:
`node backend/qa/lts_v251_probe.mjs year|invalidation|old`
Use migration tooling for the DDL probe. Inspect its private receipt for PASS,
then apply the guarded production patch and verify productive and genuinely
uncached local read-only paths. Existing checks remain enabled.

