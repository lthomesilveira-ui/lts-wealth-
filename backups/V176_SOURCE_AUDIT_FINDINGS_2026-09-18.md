# V176 — Source audit findings — 18/09/2026

Status: AUDIT COMPLETE / IMPLEMENTATION IN PROGRESS
Baseline: V175 fixed homologation
Public root: protected / unchanged

## 1. RSU shown incorrectly in cash Entradas — root cause confirmed
The canonical bank-cash day calculations are already correct. For the relevant Nov/2026 days:
- 08/11/2026: backend `fix86_columns.entradas = 0`; cash exit = R$ 2.886,43; `RSU vested` rises from R$ 15.913,44 to R$ 37.659,42.
- 10/11/2026: backend `fix86_columns.entradas = 0`; cash exit = R$ 0; `RSU vested` rises to R$ 54.970,37.

The browser Flow V12 additionally emits future-liquidity display events:
- 08/11/2026: `future_rsu_available`, Corretora, +R$ 21.745,98;
- 10/11/2026: `future_rsu_available`, Corretora, +R$ 17.310,95;
- plus a zero-value `future_award_vesting_marker`.

These events represent brokerage/RSU liquidity, not tracked bank-account cash. The base UI computed `Entradas` by summing positive day events and therefore displayed the RSU availability as a current-account entry even though the bank balance correctly ignored it.

Required correction:
- exclude future award/RSU liquidity events from cash `Entradas`, `Saídas` and cash movement detail;
- keep them represented by the `RSU vested` resource column;
- make the positive RSU increment visually explicit in that column on vesting/availability changes;
- do not alter bank cash arithmetic.

## 2. “Ocultar dias sem movimento” — root cause confirmed
The base `flowDayMaterial` kept a day visible when:
- any event existed, including a zero-value vesting marker or RSU availability event; or
- D0/RSU/FGTS/economic resource layers changed.

That conflicts with the user's definition of movement.

V176 contract:
- a day is material for this toggle iff cash `Entradas` > 0 or cash `Saídas` > 0 for the selected bank scope;
- negative/positive carried balance alone does not count;
- D0/D1, RSU, FGTS and other resource-layer changes alone do not count;
- an entry and exit on the same day still counts as movement even if the net is zero;
- explicitly activating “Ocultar dias sem movimento” disables any preset force-show behavior.

## 3. Exact expense windows audited
UI business date: 18/09/2026.

The user-facing windows are:
- 6 months: 01/04/2026 through 18/09/2026;
- 12 months: 01/10/2025 through 18/09/2026.

## 4. Saúde — V175 6m was overstated
Confirmed V175 bug:
`lts_expense_effective_rows_v175` allowed all reconciled workbook months whenever `p_from` was the first day of a month. Therefore a 6m request beginning 01/04/2026 also included workbook category allocations from Nov/2025 through Mar/2026.

V175 displayed:
- 6m Saúde: R$ 92.359,98.

Correct source-bounded V176 result:
- 6m Saúde: **R$ 56.307,56**.

6m composition:
- Saúde geral / não atribuído: R$ 36.146,23;
- Larissa: R$ 10.515,00;
- Benjamin: R$ 9.646,33.

Monthly 6m totals:
- Apr/2026: R$ 9.727,20;
- May/2026: R$ 8.623,73;
- Jun/2026: R$ 6.530,34;
- Jul/2026: R$ 8.711,38;
- Aug/2026: R$ 13.192,77;
- Sep/2026 through 18/09: R$ 9.522,14.

The corrected reader uses workbook category decomposition only for Apr/May/Jun inside this 6m selection. No pre-April workbook month can enter.

## 5. Saúde — 12m was high but not inflated by the window bug
V175 / corrected V176:
- 12m Saúde: **R$ 105.050,49**.

The amount remains source-backed after fixing the range bug because the recovered workbook months Nov/2025–Jun/2026 legitimately fall inside the 01/10/2025–18/09/2026 window.

12m composition:
- Saúde geral / não atribuído: R$ 63.800,29;
- Benjamin: R$ 23.735,20;
- Larissa: R$ 17.515,00.

V176 exposes this composition so the total is auditable rather than a single opaque number.

## 6. Empréstimos — 6m and 12m values are source-backed
No range inflation or duplicate invoice/card effect was found in Empréstimos. All rows are direct current-account events.

6m, 01/04/2026–18/09/2026:
- Itaú historical paid: R$ 20.887,85;
- Coopharma consignado: R$ 17.804,08;
- total: **R$ 38.691,93**.

12m, 01/10/2025–18/09/2026:
- Itaú historical paid: R$ 64.717,19;
- Coopharma consignado: R$ 44.510,20;
- total: **R$ 109.227,39**.

The Itaú rows are monthly direct cash payments (mostly R$ 7.304,89, with Jun/2026 R$ 6.278,07). Coopharma rows are R$ 4.451,02 monthly. These are historical paid cash outflows, not current debt stock.

## 7. Database correction
Additive V176 readers:
- `lts_expense_effective_rows_v176`: full-month workbook replacement can occur only inside the selected date range;
- `lts_browser_expense_executive_v9`;
- `lts_browser_monthly_balance_v6`;
- `lts_browser_recurring_category_gap_audit_v2`.

Applied migrations:
- `v176_expense_window_integrity`;
- `v176_health_subgroup_transparency`.

No raw financial source row was rewritten.
