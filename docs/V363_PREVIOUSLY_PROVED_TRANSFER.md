# Preserve a previously proved own transfer after a provider correction

A source-specific destination confirmation and an earlier bank observation can
already establish an own transfer. A later change to the receiving bank's payer
document must not erase that evidence or cause the same destination question again.

This patch adds a private documentary contract. It requires the existing V304
debit validator, the exact audit confirmation, an immutable earlier POSTED credit
observation with equal owner identities, current owned checking accounts,
reciprocal bank routing, identical provider transaction/account identities,
same date and opposing amounts, and exact reviewed current hashes. The private
evidence retains the payer discrepancy and correctly describes the original
confirmation as destination-only. It never fabricates a new explicit pair
confirmation or changes raw bank, account or financial-event records.

The existing shared pair reader reuses the contract across Flow, income and
classification queues. Ambiguous legs, missing/revoked evidence, changed sources,
wrong accounts/owners/currencies/status/routing and unrelated transactions remain
unqualified. Legacy explicit-pair behavior and function ACLs are preserved.

Activation is separate from schema deployment and uses private operator settings.
Run a rollback trial and compare all unrelated expenses, all raw financial
sources, per-bank cash and the receiving income queue before committing. Native
PostgreSQL tests use synthetic identities and execute the real validators and
reader; they do not certify physical-device or second-account browser sessions.
