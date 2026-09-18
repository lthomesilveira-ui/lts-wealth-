# V176 — Flow RSU / zero-movement filter / 6m-12m expense audit — 18/09/2026

Status: AUTHORIZED FOR EXECUTION / HOMOLOGATION ONLY
Baseline: V175 fixed homologation
Public root: protected; no production promotion authorized

## User feedback

### F01 — RSU must not appear in cash Entradas
Observed in Flow around Nov/2026:
- RSU events are shown in the `Entradas` column even though they do not change the bank cash balance.
- This is semantically wrong and can confuse cash reading.

Required:
- bank/cash `Entradas` and `Saídas` must contain only movements that affect tracked cash;
- RSU vesting may be displayed in `RSU vested` / RSU-specific columns in green;
- RSU must not be presented as current-account income merely because it has positive economic value;
- preserve existing cash arithmetic and planning liquidity rules.

### F02 — “Ocultar dias sem movimento” must use Entradas/Saídas only
Observed:
- days with no cash entries and no cash exits sometimes remain visible because balance/RSU/other non-cash columns change or remain non-zero.

Required:
- when the user activates `Ocultar dias sem movimento`, hide every day whose actual tracked-cash Entradas = 0 and Saídas = 0;
- balance being negative/positive is not movement;
- D0/D1, RSU, FGTS, cash-after-RSU or other columns must not keep a day visible;
- preserve days with a real cash in/out even if net movement is zero.

### F03 — Double-check 6m and 12m Despesas: Empréstimos and Saúde
User reports that the 6-month and 12-month totals for `Empréstimos` and `Saúde` look overstated.

Required audit:
1. Compute the exact date windows used by the UI.
2. Reconcile the two groups against the V175 effective expense rows.
3. Split Empréstimos by actual counterparty/lender and distinguish historical paid from debt stock.
4. Split Saúde by cash/card source and check workbook category replacement months.
5. Verify no invoice settlement, loan principal source, duplicated card aggregate, or V175 replacement logic is counted twice.
6. If totals are correct, persist exact source-backed composition and explain.
7. If inflated, correct the reader and regression-test both 6m and 12m.

## Release gate
No V176 exposure until:
- source findings are persisted;
- cash-Entradas/RSU semantics are tested;
- zero-movement filter is tested against negative-balance and RSU-only days;
- exact 6m/12m Empréstimos and Saúde source parity passes;
- V175 and protected Flow/bank/invoice regressions pass;
- public index remains unchanged.
