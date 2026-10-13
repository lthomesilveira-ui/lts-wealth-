# Realized legacy property expenses

The expense reader excluded bank movements already linked to legacy forecasts from its new-bank branch. Its realized branch handled financial events only. As a result, a proved legacy property payment could appear in Flow and be absent from Expenses.

The patch appends a realized row only when an owner-confirmed documentary binding matches the posted checking-account source, institution, signed amount, posting date and raw hash. An explicit property and purpose decision is required. Existing source identities and ambiguous bindings prevent duplication. The existing property grouping is preserved.

Validation performed with private owner data:

- Two proved legacy property payments appear once in Expenses and once in Flow.
- All 7,729 earlier expense financial identities remain unchanged; no duplicate row keys or pending expense identities.
- Existing 207 financial events and the two raw source hashes remain unchanged.
- Observed balances, cash movements, daily summaries and displayed liquidity values retain their prior values.
- A transaction rolled back after an invalid-proof probe rejects that expense and retains the independent proved expense.
- The expense reader remains SECURITY INVOKER with an empty search path and service-only access. Neither anon nor authenticated can call it directly.

Private bank rows, identifiers, balances and owner confirmations are retained in the canonical audit documents, outside this repository. Frontend assets and layout were not changed.
