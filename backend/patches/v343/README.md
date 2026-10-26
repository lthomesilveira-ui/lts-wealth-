# Original workbook inflows in spending

Some pre-2018 imported inflows have an outgoing direction in the analytical import. The original ledger and the original cash-flow income block identify the affected receipts and asset withdrawals. This patch changes only their eligibility for spending, using separately supplied private documentary evidence.

Acceptance requires exact owner, source index, entire current source payload, date, positive amount, description, category, original workbook hash, ledger row multiplicity and explicit income-block locator. Conflicting evidence or a later per-source owner decision prevents acceptance. Equal source tuples remain distinct; their documentary multiplicity must agree. The original cached daily date headers are unavailable in this interval, so this contract does not certify historical daily balances or rewrite cash.

The internal view uses invoker security and service-only access. The existing realized-expense view retains its OID, owner, grants, options and columns; its only changed field is the spending exclusion for proved sources. Existing evidence triggers invalidate derived readers. Private activation must refresh the expense cache and compare complete before/after row sets: only the proved sources may disappear from spending. No financial source, amount, date, sign, classification, balance, forecast or payment is mutated.

Native PostgreSQL tests use synthetic evidence only. They cover eligibility, rejection of altered identities and evidence, duplicate/conflicting proofs, later decisions, multiple owners, unchanged sources/cash fields, view privileges, replay and the original view lease. They do not certify complete historical reconciliation, a private browser session or a physical device.
