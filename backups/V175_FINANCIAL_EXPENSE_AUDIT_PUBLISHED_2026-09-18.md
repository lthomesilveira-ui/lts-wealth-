# V175 — Financial expense audit published to homologation — 18/09/2026

Status: PUBLISHED TO FIXED HOMOLOGATION / PUBLIC ROOT NOT PROMOTED

## Release identity
- source branch: `work/v175-expense-financial-audit-20260918`;
- validated product head: `c8144dfb4f00ce40b6c24a4616b055cf3a4d8dce`;
- V175 branch gate: GitHub Actions `35386909885` — SUCCESS;
- pull request: #20;
- merge to `main`: `f198c0e4e00540d3e4d2e2649b7003b7618008b1`;
- manifest exposure: `9b55e58e2d8bd0feb0b1cbcad020a0094116b2b3`;
- Pages deployment: `35389818312` — SUCCESS;
- fixed homologation candidate: `wip35-v175-candidate.html`;
- public `index.html`: not promoted / protected.

## Closed in V175
- historical workbook card-category evidence recovered with exact monthly-total parity;
- Restaurant/iFood/Rafiki blank months Dec/2025 through Mar/2026 corrected from preserved source evidence;
- false R$ ~567k `Itaú` loan subgroup eliminated; lender split uses counterparty, not bank account;
- Itaú historical paid amount identified as R$ 267.441,25; CooperMSD R$ 224.164,59; Coopharma R$ 84.569,38; CGI/CEF/Funcef separate;
- full-history monthly reader returns 156 months and client uses bounded annual summary + selected-year detail instead of rendering 156 × ~90 groups;
- Sep/2026 share-sale evidence R$ 18.808,69 restored from confirmed C6 Global context, while downstream transfers stay neutral;
- historical card inventory includes Itaú Mastercard/Personnalite lineage, Visa Itaú, Visa Infinite Itaú, Bradesco Aeternum, Bradesco Visa/Infinite Prime, C6 historical 6610 and C6 Carbon 7873/8304;
- property works full-history presentation uses reconciled R$ 2.174.777,52 and preserves the R$ 2.937,26 source duplicate as evidence;
- Família expense rows were audited as actual negative/outgoing cash events; presentation remains `Família — saídas`;
- V175 Supabase QA `lts_v175_financial_audit_qa_v1` passed every check.

## Open and explicit
- Apr/2026 share sale: user confirms it occurred, but no source amount was found in preserved bank/financial/workbook evidence. It is stored as `stock_sale_2026_04_missing_source` and is deliberately not fabricated.
- Historical months that still have aggregate invoice totals without line/category detail remain labeled as unresolved coverage rather than zero/category invention.
- Human authenticated notebook/phone acceptance remains required.

## Persistence outside chat
- scope: `backups/V175_DEEP_FINANCIAL_EXPENSE_AUDIT_SCOPE_2026-09-18.md`;
- source findings: `backups/V175_SOURCE_AUDIT_FINDINGS_2026-09-18.md`;
- recovered monthly workbook evidence: `backups/V175_WORKBOOK_MONTHLY_CATEGORY_SOURCE_2026-09-18.json`;
- canonical reader snapshot: `supabase/canonical_v175_expense_financial_audit_2026_09_18.sql`.
