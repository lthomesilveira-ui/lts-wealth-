# V177 — Source audit findings — 18/09/2026

Status: SOURCE AUDIT COMPLETE / UI IMPLEMENTATION IN PROGRESS
Baseline: V176 fixed homologation
Public root: protected / unchanged

## 1. 2020 expense audit — source-backed result
The user's concern was valid to investigate because the full-year average falls from R$ 53.911,10/month in 2019 to R$ 23.448,14/month in 2020.

Exact effective-expense totals:
- 2019: R$ 646.933,25; average R$ 53.911,10/month.
- 2020: R$ 281.377,71; average R$ 23.448,14/month.
- 2021: R$ 793.706,25; average R$ 66.142,19/month.

The key 2019 non-recurring driver is `Casamento`:
- Casamento in 2019: R$ 344.846,71.
- 2019 excluding Casamento: R$ 302.086,54.
- normalized 2019 average: R$ 25.173,88/month.
- 2020 versus normalized 2019: -R$ 20.708,83 for the year, or -6,86%.

Conclusion:
- the apparent ~56% collapse is mostly a composition effect caused by the wedding year;
- normalized 2019 and 2020 are close enough that 2020 is not intrinsically anomalous on total spend.

## 2. 2020 source completeness checks
2020 contains expense evidence in every month.

2020 card evidence:
- 12/12 months have card cash/fatura evidence;
- total card spend: R$ 99.107,08;
- all documented 2020 card settlement is Mastercard Itaú;
- no Visa settlement is present in the preserved 2020 source.

2019 card evidence for comparison:
- Mastercard Itaú: R$ 164.402,94;
- Visa: R$ 79.725,58;
- total: R$ 244.128,52.

2020 monthly card totals are present every month:
- Jan R$ 10.090,94
- Feb R$ 8.010,26
- Mar R$ 7.293,60
- Apr R$ 4.217,90
- May R$ 4.359,11
- Jun R$ 11.943,20
- Jul R$ 11.018,18
- Aug R$ 9.731,80
- Sep R$ 7.969,92
- Oct R$ 8.914,44
- Nov R$ 7.659,10
- Dec R$ 7.898,63

No month is absent from the card ledger. The documented disappearance of Visa is therefore not a missing-month bug in the current source set.

## 3. Property / apartment roll-up
Approved management hierarchy implemented in the backend:
- `Apartamento · CIPÓ 396`
  - Aquisição do imóvel
  - Financiamento imobiliário
  - Obra e reforma
  - Custos recorrentes de moradia

Full-history cash directed to the apartment:
- Aquisição do imóvel: R$ 288.747,56
- Financiamento imobiliário: R$ 1.700.952,62
- Obra e reforma: R$ 2.174.777,52
- Custos recorrentes de moradia: R$ 364.579,90
- Total cash directed to Apartamento · CIPÓ 396: **R$ 4.529.057,60**

Recurring housing-cost composition:
- Condomínio: R$ 236.934,10
- IPTU e impostos do imóvel: R$ 69.235,37
- Energia elétrica: R$ 57.052,03
- Seguro residencial: R$ 1.358,40

The roll-up is a cash-management view. Acquisition, financing, works and recurring occupancy costs remain separate and are not semantically collapsed.

## 4. Group transaction drill-down
New backend function `lts_browser_expense_group_detail_v1` returns the economic rows underlying a management group for the selected period.

Family validation:
- `Família — saídas`: R$ 263.909,54;
- 202 rows;
- detail total = management-group total exactly.

Apartment validation:
- `Apartamento · CIPÓ 396`: R$ 4.529.057,60;
- 726 detail rows/components;
- detail total = apartment roll-up exactly.

Detail fields exposed to the professional UI:
- date / historical period label;
- description/history;
- account/card source;
- center/counterparty where useful;
- value;
- property component when applicable.

For source-only historical work components where an individual purchase date was never documented, the UI must show `Histórico`, not fabricate a date.

## 5. Front-end cleanup
The normal product UI must not display:
- `fonte reconciliada`;
- original workbook amount;
- duplicate-source calculation;
- source-contract/programming wording.

Those facts remain in audit checkpoints and database contracts, not in the user-facing management screen.

## 6. Database objects
Applied additive migration:
- `v177_property_rollup_drilldown_2020_audit`

New functions:
- `lts_v177_property_component_v1`
- `lts_v177_recurring_housing_detail_v1`
- `lts_browser_property_rollup_v1`
- `lts_browser_expense_executive_v10`
- `lts_browser_expense_group_detail_v1`
- `lts_v177_2020_expense_qa_v1`

No raw financial source row was rewritten.
