# Confirmed recurring person transfers

The actual review reader hid every suggestion for outgoing PIX/TED to CPF,
including exact recipient/amount/account occurrences already confirmed by the
owner. Merchant/card learning worked, but this unconditional guard suppressed
the known transfer recurrence.

This read-only correction permits a suggestion only from an explicit prior
owner decision on an undeleted, posted checking-account transfer within one
year. It requires the same provider, institution, account, currency, signed
amount, operation and recipient document, consistent active categories, and an
exact match between requested target fields and the owned source. The recipient
document remains internal. The output contains prior source/date/category proof,
always requires confirmation, and never infers the patient/beneficiary from the
recipient. Missing identity, conflicts, other amounts/accounts/directions and
automatic merchant labels retain the previous behavior.

No decisions, expenses, balances, source payloads, identities, permissions,
frontend assets or release pointers are written. Installation and rollback are
guarded against concurrent function changes. Native PostgreSQL17 tests use the
actual original/patched SQL body, invented data, isolation/negative controls,
source/decision hashes and guarded idempotent lifecycle. Actual published-reader
acceptance remains a separate installation gate.
