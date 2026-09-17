# V171 — V170 review closure published

Date: 17/09/2026  
Status: PUBLISHED IN FIXED HOMOLOGATION; PUBLIC ROOT UNCHANGED; HUMAN ACCEPTANCE PENDING

## Authorization and lineage

The user authorized autonomous implementation and publication only in homologation for `lthomesilveira-ui/lts-wealth-`.

- Previous main: `c0a94e6d48ab0ded8dcce09a46921fd70216e05a` at implementation start.
- Tested V171 branch head: `f3bf16abc2cf917c5e7a80deb55bd5366fd515b5`.
- Squash merge on main: `b4cf631d7caaca7f34ebc2fef177402e1bad0261`.
- Branch: `work/v171-v170-user-review-20260917`.
- Candidate: `wip35-v171-candidate.html`.
- Pull request: `#12`.

No public promotion was authorized. `index.html` remained byte-for-byte unchanged with SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`.

## Delivered scope

- Professional expense taxonomy separates recurring expenses, investments in property/works and every financing class.
- Only explicit Benjamin education is `Benjamin — Educação`; remaining education is `Educação`.
- Dashboard presents Top 12 management groups and a distinct expense color.
- Despesas presents Top 15, open subgroup composition, full-period monthly balance, working transactions and bank → named card → month future-card reading.
- Audited live reader totals include works/reform R$ 1.517.643,79; real-estate financing R$ 1.700.952,62; loans/consignado R$ 651.990,34; Benjamin education R$ 56.267,53; other Education R$ 86.647,00; Rafiki R$ 29.769,84.
- Historical card aggregates remain in total reconciliation and are not assigned to invented merchants or groups.
- Flow removes internal “Histórico auditável” language, retains `RSU vested` and `Saldo c/ RSU`, loads progressively and defaults to five prior days through the next year end.
- Layered legacy boot callbacks can no longer reopen a 30-day range or block the product.
- Patrimônio keeps Morgan statement gross/available/after-reserve figures separate and supports both bulk and individual vesting price/FX controls.

## Database and security

Applied migrations:

- `20260917175647_v171_professional_expense_taxonomy_monthly_balance.sql`;
- `20260917180229_v171_expense_coverage_aggregation_fix.sql`.

Authenticated browser readers are `lts_browser_expense_executive_v6` and `lts_browser_monthly_balance_v2`. Post-DDL security/performance advisors showed only pre-existing RLS information and unrelated health-table performance findings; no new V171-table finding was introduced.

## Automated evidence

- Final V171 gate: `35264916304` — SUCCESS.
- Tested branch head: `f3bf16abc2cf917c5e7a80deb55bd5366fd515b5`.
- Desktop: 1440 × 1000 — PASS.
- Mobile: 390 × 844 — PASS.
- Protected Flow, invoice, bank-scope, reading-order and documentary-rollforward contracts — PASS.
- Static contract confirms protected public index unchanged — PASS.

The gate covers route loading, expense groups/subgroups, full-period monthly balance, cards, expense transactions, Morgan gross/net/available presentation, bulk vesting mutation parameters under controlled fixture, next-year Flow opening, historical opening/closing balances, internal-transfer arithmetic and responsive overflow. Controlled fixtures are not the user's private values.

## Remaining gate

The user should perform human authenticated review in the fixed homologation link. Public-root promotion remains a separate explicit decision and was not performed.
