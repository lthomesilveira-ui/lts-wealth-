# V176 — Flow RSU and expense-window audit published — 18/09/2026

Status: PUBLISHED TO FIXED HOMOLOGATION / PUBLIC ROOT NOT PROMOTED

## Release identity
- source branch: `work/v176-flow-rsu-expense-window-audit-20260918`;
- validated branch head: `05001c7a79b077425fc60804aceff0ffa829bf17`;
- V176 branch gate: GitHub Actions `35392138400` — SUCCESS;
- Supabase QA: `lts_v176_expense_window_qa_v1` — PASS;
- product merge to `main`: `5cd67fef7ee4080ba7d38dda0219ac646240fcf5`;
- manifest exposure: `3fea384ce5b989a0fa9596697e1967617081873a`;
- Pages deployment: `35392557385` — SUCCESS;
- fixed homologation candidate: `wip35-v176-candidate.html`;
- protected public `index.html`: not promoted / unchanged.

## Closed in V176
- RSU availability/vesting events no longer count as bank/current-account `Entradas` or `Saídas`;
- RSU increases remain in the `RSU vested` liquidity column, with a green delta on dates where the available/vested position increases;
- `Ocultar dias sem movimento` now uses only actual cash Entradas/Saídas for the selected bank scope;
- carried negative/positive balances, D0/D1, RSU, FGTS and resource-layer changes alone no longer keep a day visible;
- explicit hide-zero disables any preset force-show flag;
- V175's 6-month Saúde total was proven overstated by an expense-window bug and corrected from R$ 92.359,98 to **R$ 56.307,56**;
- 12-month Saúde was re-audited and remains **R$ 105.050,49**, source-backed;
- 6-month Empréstimos was re-audited at **R$ 38.691,93**, source-backed;
- 12-month Empréstimos was re-audited at **R$ 109.227,39**, source-backed;
- Saúde is now decomposed into Saúde geral / não atribuído, Benjamin and Larissa;
- V176 effective expense reader prevents workbook category rows from months before the selected window from entering 6m/12m totals.

## Exact expense audit
6m window = 01/04/2026–18/09/2026:
- Empréstimos: Itaú historical paid R$ 20.887,85 + Coopharma R$ 17.804,08 = R$ 38.691,93;
- Saúde: Saúde geral / não atribuído R$ 36.146,23 + Larissa R$ 10.515,00 + Benjamin R$ 9.646,33 = R$ 56.307,56.

12m window = 01/10/2025–18/09/2026:
- Empréstimos: Itaú historical paid R$ 64.717,19 + Coopharma R$ 44.510,20 = R$ 109.227,39;
- Saúde: Saúde geral / não atribuído R$ 63.800,29 + Benjamin R$ 23.735,20 + Larissa R$ 17.515,00 = R$ 105.050,49.

## Persistence outside chat
- user feedback: `backups/V176_USER_FEEDBACK_REGISTER_2026-09-18.md`;
- source findings: `backups/V176_SOURCE_AUDIT_FINDINGS_2026-09-18.md`;
- canonical database snapshot: `supabase/canonical_v176_flow_expense_audit_2026_09_18.sql`.

No raw financial source row was rewritten by this release.
