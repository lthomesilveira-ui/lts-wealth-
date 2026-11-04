# V410 — keep opened recurrence reviews visible

The audit discovers recurring series from historical activity. That signal can
age out after120 days, then400 days, or the36-month history window. Previously,
an unresolved planning review could therefore disappear without a decision.

V410 changes only `lts_recurring_future_gap_audit_v6(uuid,date,date)`. The existing
detectors, cash-flow readers, payment evidence and cancellation rules are retained.
The function also reads the owner's dedicated
`legacy_namespace.chave = 'lts_recurring_review_scope_v410'`. Open tracked identities
are added only when absent from the native specifications. Existing native items
remain identical when the scope contains only open reviews.

## Stored scope

`valor_bruto` contains JSON with schema `lts-recurring-review-scope-v1` and a nonempty
`entries` array. `sha256` is SHA-256 of the exact UTF-8 text, as for other namespaces.
Each entry contains an existing control reference, a nonempty canonical key/title,
direction, cadence of **review**, opening date and embedded opening evidence with
its reference and content digest. It contains no amount, due day or payment.

`decisions` is an ordered metadata history. A closure is eligible only when it
declares `scope = whole_series_review`, has action `end` or `replace`, an increasing
revision, applicable effective/decision dates, and explicit owner evidence with
owner ID, recoverable reference, embedded text and matching digest. Replacement
also requires a distinct, known canonical target with the same direction. A later
explicit `open` can reopen the review. Classification, lexical similarity and
one-occurrence cancellation do not close a whole review.

This is a validated reading contract, **not a new decision-writing interface** or
an enforced immutable journal. Operators must preserve prior entries/decisions,
use the previous namespace digest as a write lease, and audit any authorized
change. No new writer RPC, frontend flow, table or recurring plan is introduced.

Effective closures are filtered from both horizon specifications and the legacy
item arrays, preventing the published Actions fallback from rediscovering them.
If the existing audit reports an earlier unconfirmed obligation, the review stays
visible. This guard covers the existing current-month obligation scope; it does
not certify settlement of earlier months. Closing a future-planning review never
marks a payment, clears a ledger obligation, or changes reconciliation history.

## Invalid data and the published interface

Unreadable scope, invalid opening identity/source, duplicate identities or a
digest mismatch raises SQLSTATE22023. The published V407 consumer already handles
RPC failure with a visible update warning and retry action. It preserves its last
successful list; an initial failure shows unavailable counts, not a successful
zero. New JSON-only error fields would be ignored by that consumer, so V410 does
not use them. An invalid closure is ignored and the valid opening remains visible.
Additional `review_reason` metadata is not claimed to be displayed verbatim by V407.

## Deployment, backup and compensation

Apply `persistent_review_scope.sql` atomically. It leases the exact public V371
predecessor and preserves the function's owner, ACL, security-definer setting,
search path, timezone and other attributes. Its implementation language changes
from SQL to PL/pgSQL for explicit validation and error handling. Exact replay is a
no-op. The public V371 source is the baseline; no live data is bundled here.

The owner-specific seed is private and separately reviewed. It records only
already-open controls and no closure decisions. The generic migration writes no
namespace or financial data. Existing namespace triggers invalidate derived cash
caches when that private metadata is inserted or changed.

The existing legacy backup exports every namespace for the owner, without a key
allowlist. V406 retains that legacy component; no backup change is necessary.
The namespace stores its own recoverable evidence. `audit_log` is an additional
trail, not the only source of operational state.

`rollback.sql` restores the exact predecessor while retaining namespace history.
Private metadata compensation archives the unchanged namespace under a distinct
key and records an audit event; it is an operational rollback, not a declaration
that the tracked reviews have been resolved. Financial sources are preserved.

## Verification

`python3 backend/tools/recurring_review_v410/test_sql.py` emits a self-contained
synthetic PostgreSQL17 transaction. The native CI workflow runs it with `psql`.
Tests execute the actual public reader bodies, with explicitly synthetic
dependencies. They cover the unchanged absent-scope baseline;16 identical native
items plus one tracked monthly review;119/120/121 and400/401 days and beyond36
months; owner isolation; malformed scope; invalid and temporal decisions; legacy
fallback; replacement identity; reopening; existing pending evidence; namespace
export/reimport; financial-source preservation; ACL/config; replay and rollback.

These synthetic checks do not certify a private session, actual device, complete
database restoration or settlement. Owner-specific before/after proofs remain
private and must use the actual transaction baseline.
