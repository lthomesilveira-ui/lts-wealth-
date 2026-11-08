# Keep a reviewed C6 receipt valid when later-cycle payments are appended

The issuer can append a later month's payment to an older invoice's payment
array. The reviewed older receipt and checking debit remain unchanged, but the
whole-array equality in two readers rejects them and the UI shows the old
invoice as unpaid again.

The patch preserves every reviewed payment and every other invoice field.
For the existing, specifically reviewed C6 policy only, an added payment is
accepted when it has a distinct ID, valid civil date strictly after the reviewed
payment, positive numeric BRL amount, and the expected payment type and mode.
The existing cycle selector must still return the exact original receipt.
Changed, removed, duplicate, ambiguous, same-cycle or malformed evidence fails
closed. Other banks retain the original equality checks.

This changes no raw source, contract, classification, invoice amount, payment,
cash movement, recurring plan, schedule, retention policy or frontend release.
Exact predecessor, attributes, owner, security, grants and replay checks apply.
The helper has service-only access and no table reads or writes.

The native PostgreSQL 17 test reproduces the predecessor failure and checks the
two actual readers with invented data, later-list additions and reordering,
negative evidence cases, original receipts, other-bank receipts, permissions,
source immutability and replay. Production acceptance additionally requires
read-only comparison with existing private evidence and the authenticated UI.
Passing the invented tests alone does not complete any financial backlog item.

References: [Postgres JSON operators](https://www.postgresql.org/docs/17/functions-json.html)
and [database functions](https://supabase.com/docs/guides/database/functions).
