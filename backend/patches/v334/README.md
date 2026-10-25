# Exact received descriptor in coverage audit

An already posted direct debit was absent from its recurring series because its
bank descriptor includes a payment-method prefix. V334 recognizes that exact
normalized descriptor in the bank-actual branch of the coverage audit. Existing
documentary identities and explicit beneficiary/category context keep priority.
It does not widen the global series-key helper or use fuzzy merchant matching.

Only a BRL, posted, nondeleted checking-account transaction for the requested
owner and elapsed current-month date can cover the period. A pending payment,
refund, other owner, unsupported resource or future date cannot do so. Later
months keep their existing coverage review; no renewal, value, payment or cash
event is inferred. Raw sources, classifications and projections remain unchanged.

The patch leases the inspected function definition, preserves all other pg_proc
attributes and is a no-op on exact replay. Native PostgreSQL tests exercise the
actual audit body with isolated dependency doubles and source rejection cases.
Those tests do not certify a production HTTP session or a full database restore.
