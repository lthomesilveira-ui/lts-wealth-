# V177 — Expense audit / apartment roll-up / drill-down published — 18/09/2026

Status: PUBLISHED TO FIXED HOMOLOGATION / PUBLIC ROOT NOT PROMOTED

## Release identity
- source branch: `work/v177-expense-audit-drilldown-property-ux-20260918`;
- validated branch head: `eff2412c6ffc3184799220bc2a0ca1d526c4a0f8`;
- V177 branch gate: GitHub Actions `35396351907` — SUCCESS;
- Supabase QA: `lts_v177_product_qa_v1` — PASS;
- product merge to `main`: `49b8a0742b80409e728abff81f2fb67fcf0d5cc3`;
- manifest exposure: `d0c73d8a0e5589a74a2c3e1ad24b796e2a4ff00b`;
- Pages deployment: `35396641223` — SUCCESS;
- fixed homologation candidate: `wip35-v177-candidate.html`;
- protected public `index.html`: not promoted / unchanged.

## Closed in V177
- 2020 expense anomaly was audited: 2019 R$ 646.933,25 vs 2020 R$ 281.377,71, but R$ 344.846,71 of 2019 was Casamento. Normalized 2019 excluding Casamento is R$ 302.086,54, only 6,86% above 2020.
- 2020 has card evidence in all 12 months; card total R$ 99.107,08 and preserved source shows Mastercard Itaú only, with no Visa settlement in 2020.
- Property groups are consolidated into `Apartamento · CIPÓ 396` while acquisition, financing, works and recurring housing costs remain distinct.
- Full-history apartment cash roll-up: R$ 4.529.057,60.
- Subgroups: Aquisição R$ 288.747,56; Financiamento R$ 1.700.952,62; Obra e reforma R$ 2.174.777,52; Custos recorrentes de moradia R$ 364.579,90.
- Recurring housing costs: Condomínio R$ 236.934,10; IPTU/impostos do imóvel R$ 69.235,37; Energia elétrica R$ 57.052,03; Seguro residencial R$ 1.358,40.
- Normal front-end no longer shows `fonte reconciliada`, original-workbook/duplicate reconciliation strip or source-contract/programming wording in the expense composition.
- Management-group values are clickable. A professional drawer lists date/period, description/history, account/card, reference and value.
- Família — saídas drill-down reconciles exactly to R$ 263.909,54 across 202 rows.
- Apartamento drill-down reconciles exactly to R$ 4.529.057,60 across 726 transactions/components.
- Historical work components without individual purchase dates display `Histórico`; no date is fabricated.

## Persistence outside chat
- feedback decisions: `backups/V177_USER_FEEDBACK_REGISTER_2026-09-18.md`;
- source audit: `backups/V177_SOURCE_AUDIT_FINDINGS_2026-09-18.md`;
- canonical database snapshot: `supabase/canonical_v177_expense_ux_2026_09_18.sql`.

No raw financial source row was rewritten by this release.
