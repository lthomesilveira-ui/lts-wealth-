# Incoming classifications and Actions

Apply `income_review.sql`, `bank_income_reader.sql`, `api_boundary.sql`, then
`monthly_income_sources.sql` in the same release window.
The latter is the final source-only reader: it intentionally avoids rendering
cash balances, card invoices and their projections while listing receipts.
Existing releases and public write signatures are preserved.
The public queue is an invoker-only wrapper around a private, owner-checked reader.
The monthly V229 report reuses the same realized receipt identities. Historical
excluded rows remain excluded and the existing extraordinary/expense criteria
are preserved. Private compatibility layers omit the redundant older expense
passes; V229 computes canonical expenses once, including the coverage counters.
Older report APIs remain unchanged. The internal worker remains service-only and
also checks the owner; API queue/writer callers assert the owner before invoking it.

The checking source cutover uses each bank's documentary opening and received
position. Existing documentary identity and confirmed own-transfer decisions are
reused. The review queue includes the historical ledger, not every overlapping
raw provider transaction. Unresolved purposes remain visible; no person is inferred.

`backend/operations/extend_confirmed_income_sender_v296.sql` accepts private,
source-pinned settings and extends an existing explicit owner-confirmed income
rule. It is not a generic merchant-name classification operation. Snapshots and
the prior rule are recorded privately. No personal data or source IDs are in this
repository's fixtures.

The category writer changes only the exact source's classification decision,
requires an optimistic preview token, reads the shared category registry and
audits the operation. `backend/qa/lts_v296_income_review_rollback.sql` exercises
bank and historical writers inside a rolled-back transaction and checks all
financial sources and expenses for unintended changes.
