# V162 — Invoice reading order and classification readiness

12/09/2026. The user says the inspected Flows now appear correct, asks for descending invoice categories without searching across two columns, and asks when accumulated classification can begin. This is partial practical feedback, not full approval of all modules or bulk classification.

## Presentation candidate
The same invoice model now uses one vertical category/value list in descending net total order. No two-column alternation. The existing sorting, pending category, credits, source amounts and full purchase details are untouched. CSS is scoped to the isolated candidate; protected index.html is unchanged. All supported bank/card families share the rule, including open/closed invoices and full detail.

The package retains the already committed bank-context fix: change bank -> close expanded days and invoice panels; keep the chosen period; late requests cannot reopen the prior invoice. The exact earlier bank-context draft passed all three workflows but had not been exposed. This release must rerun its regressions together with the new reading-order geometry gate before main publication. There are no new financial writes in this UI change.

## Real readiness audit — not only a fixture
Read-only authenticated database queries found that the current Aeternum source and the Updates classification queue do NOT represent the same snapshot. The invoice-detail reader uses the verified current open source; the queue still derives that cycle from the older legacy detail. The counts/amounts differ. Also, the bank/Flow semantic queue reports no groups even though several actual Flow movements remain unclassified. This makes a blanket release of two-month manual classification premature.

The existing save function can persist an exact-description rule and separately return a deferred cache-refresh error. The protected browser handler checks transport error only and does not inspect that cache-refresh result before displaying success. Prior stateful fixture save/reload checks are useful but do not prove all current real-source queues are consistent. No new classification was guessed and no user data was changed by this diagnosis.

The next semantic package must: align current invoice/Flow review sources and counts; recover original spreadsheet/LTS mappings with user confirmations taking precedence; distinguish genuine unknowns from lost linkage; verify source readback after a save and report saved-but-not-reflected rather than false full success; refresh affected Flow caches without changing money; and preserve per-description versus per-transaction scope and all taxonomy guardrails. Do not ask the user to redo previously known mappings or use issuer categories as replacement taxonomy.

Manual bulk release remains open. The blocker is these concrete source/readback inconsistencies, not the Dashboard, Work credits or another data upload. The separate Bradesco-yield correction remains applied; do not reintroduce its resolved warning.

## Evidence and continuity
The exact private query receipt belongs in owner-scoped source_documents with audit_key invoice_linear_classification_readiness_20260912_v1; public code must not contain private merchant/amount data. Required tests: previous recovery, default-window, integrated invoices, bank context and the new single-column geometry check on notebook, desktop and mobile Chromium/WebKit. Record actual run IDs, visual inspection and main publication separately; do not claim signed-in physical-device E2E.

Retain all prior unresolved current other-Visa documentary identities, actual-session classification gate, source evidence, dates, financing/Larissa/insurance/Cofrinho decisions and the entire master backlog. Start from LTS_WEALTH_EXECUTION_STATE.md and this checkpoint on continuation.
