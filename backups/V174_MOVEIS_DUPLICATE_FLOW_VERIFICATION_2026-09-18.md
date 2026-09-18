# V174 — Móveis duplicate flow verification — 18/09/2026

Status: VERIFIED AGAINST REAL FLOW / NO DOUBLE CASH EXIT OF R$ 2.937,26
Baseline: V173 fixed homologation
Public root: protected / unchanged

## Question
The workbook source contains an internal duplicate treatment of the R$ 2.937,26 `Móveis - O Parque` amount. Verify whether R$ 2.937,26 actually left the bank twice before treating the second source occurrence as a spreadsheet duplication.

## Real ledger evidence
`lts_expense_realized` contains exactly two real Itaú cash-out rows for `Móveis - O Parque`:
- 26/11/2024: R$ 1.780,00, source `evento_base:2322`;
- 11/02/2025: R$ 1.157,26, source `evento_base:2502`.

Total economic cash outflow:
- R$ 1.780,00 + R$ 1.157,26 = R$ 2.937,26.

There is no second R$ 2.937,26 bank outflow in the realized expense ledger.

## Daily Flow verification
The same two rows are returned by the canonical corrected Flow reader `lts_corrected_cashflow_fix86_v4`:
- 26/11/2024, Itaú, `Móveis - O Parque`: signed amount -R$ 1.780,00;
- 11/02/2025, Itaú, `Móveis - O Parque`: signed amount -R$ 1.157,26.

Both are `legacy_fix86`, assigned to Itaú, non-displaced, with source refs `evento_base:2322` and `evento_base:2502`.

Canonical Flow total for these two events:
- -R$ 2.937,26.

No additional `Móveis - O Parque` Flow row or a second -R$ 2.937,26 occurrence was found.

## Workbook reconciliation
The private CIPÓ source reconciliation records:
- account-current Móveis component: R$ 2.937,26;
- Visa Infinite Móveis: R$ 50.012,90;
- Visa Bradesco Móveis: R$ 31.000,44;
- Mastercard Móveis: R$ 7.857,12.

Unique reconciled Móveis total:
- R$ 91.807,72.

Workbook summary Móveis:
- R$ 94.744,98.

Difference:
- R$ 2.937,26.

Therefore the workbook summary includes the account-current R$ 2.937,26 economic amount one extra time. The bank/Flow evidence supports counting the economic cash occurrence once only.

## Conclusion
The R$ 2.937,26 issue is a source-spreadsheet aggregation duplication, not a second bank cash exit. The reconciled financial treatment `do_not_duplicate_ledger_or_cost_from_source_duplicate` remains correct.

No database write or source mutation was performed by this verification.
