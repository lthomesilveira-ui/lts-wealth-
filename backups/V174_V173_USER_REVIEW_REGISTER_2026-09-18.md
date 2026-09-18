# V174 — V173 user review register — 18/09/2026

Status: OPEN FOR INVESTIGATION / HOMOLOGATION ONLY
Baseline: V173 fixed homologation
Public root: protected; no production promotion authorized

## Continuity rule
This register exists so the user review below never depends on chat memory. Preserve the V173 candidate and all prior evidence. Do not change financial facts until the source mismatch is explained with row-level evidence.

## U01 — Property investment / works total does not reconcile to source spreadsheet

Observed in V173, Despesas > Categorias, full-period selection:
- `Investimentos no imóvel — obra e reforma`: R$ 1.517.643,79.

User-provided source spreadsheet evidence:
- line `Outros` in the CIPÓ 396 investment summary: `Pago` = R$ 2.177.714,78.
- The user expects the app's full-history property works/reform investment grouping to reconcile to this paid amount unless a documented semantic exclusion explains the difference.

Measured gap to investigate:
- R$ 2.177.714,78 - R$ 1.517.643,79 = R$ 660.070,99.

Required investigation:
1. Trace every row currently included in `Investimentos no imóvel — obra e reforma`.
2. Trace every property/works-related row outside that group that could correspond to the spreadsheet's `Outros` subtotal.
3. Compare category, center_cost, source_table, source_ref, date and amount.
4. Separate true exclusions (e.g. financing, property purchase, recurring condominium/IPTU/energy if the spreadsheet subtotal excludes them) from mapping omissions.
5. Do not force the reader to R$ 2.177.714,78 by hardcoding or balancing entries.
6. If the spreadsheet and ledger universes differ, explain the exact components and preserve both meanings explicitly.
7. If the app is missing rows that are already present in the source ledger, correct the management mapping and regression-test exact parity.

## Acceptance
- The full-period works/reform group has a mathematically traceable relationship to the source spreadsheet.
- Any remaining difference is explicitly attributable to named rows/categories, not an unexplained residual.
- V173 remains recoverable and unchanged until a validated successor is published.

## U02 — Extraordinary share / RSU sale income is understated
Observed:
- Monthly balance now shows `Venda de ações, RSUs e outros ativos`, but the amount is materially too low.
- User reports these sales are typically around R$ 19k–20k and happen in most months.
- Operational pattern: proceeds commonly arrive in C6 Bank and are then transferred internally to Itaú/Bradesco.

Required:
1. Identify sale-proceeds rows separately from subsequent internal transfers.
2. Ensure one economic income event is counted once as extraordinary income.
3. Ensure C6 → Itaú/Bradesco transfers have zero consolidated revenue effect.
4. Audit the complete supported history, month by month, rather than fixing one month.

## U03 — Monthly expense balance appears to miss recurring restaurant / iFood activity
Observed:
- Some months in Balanço mensal show no Restaurants or iFood despite these being frequent expenses.

Required:
1. Cross-check monthly expense groups against all effective card + current-account consumption.
2. Identify whether missing months are caused by category mapping, invoice-only coverage, date/competence assignment, or reader omissions.
3. Do not fabricate category detail for aggregate-only invoices; disclose/document any month where only invoice total exists.

## U04 — Família is usually income, but appears under expenses
Observed:
- `Família` appears in Despesas > Categorias and monthly expense views.
- User states Família is generally an entry/income classification, not an expense.

Required:
1. Audit every `Família` row with direction/nature/source evidence.
2. Move no row by assumption; distinguish real outgoing family-related payments from incoming family receipts.
3. Fix expense readers if they are including income rows as expense.
4. Preserve canonical `Família` category for reviewed input.

## U05 — Loan total inconsistency / large Itaú amount
Observed:
- Despesas > Categorias loan split appears plausible (Itaú + Coopharma).
- Another product area reportedly shows an Itaú loan close to R$ 500k, which appears wrong.

Required:
1. Locate every product surface/read-model that presents loan/financing totals.
2. Reconcile current payoff/debt vs historical paid expense vs scheduled remaining outflow.
3. Never label cumulative historical payments or future scheduled outflow as current debt unless the documentary contract supports that meaning.

## U06 — Full-period Monthly Balance does not load from 2013
Observed:
- Selecting `Desde 2013` in Balanço mensal leaves the report blank / does not complete.

Required:
1. Reproduce on V173.
2. Trace client chunking, reader range, timeout/error handling and render lifecycle.
3. Long-period failure must not blank already available annual chunks.
4. Validate desktop and mobile.

## U07 — Rafiki expenses absent / understated in monthly balance
Observed:
- User expects materially more Rafiki expenses; monthly balance does not show expected activity.

Required:
1. Audit `Rafiki`, aliases (including legacy Pet) and center-cost mappings.
2. Reconcile category view, transactions and month-by-month totals.
3. Ensure legacy alias normalization does not drop rows.

## U08 — Cards & invoices future/current values disagree with Flow
Observed example:
- Visa Aeternum September: about R$ 24.390,64 appears plausible.
- October in `Cartões e faturas`: R$ 5.318,86 shown.
- User reports the Flow has the correct October amount near R$ 20k.

Required:
1. Reconcile all cards and months, not only October Aeternum.
2. For each bank/card/month, distinguish observed invoice, contracted installment floor, current purchases and Flow amount.
3. If an observed/current invoice exists, it must not be replaced by an installment-floor subtotal.
4. Validate reading precedence against the protected invoice/Flow contracts.

## U09 — Deep Despesas audit before next homologation
Scope:
- Visão geral
- Categorias
- Cartões e faturas
- Lançamentos
- Balanço mensal
- extraordinary income interaction with monthly balance

Acceptance:
- category and monthly totals reconcile to supported source rows;
- card + account expenses combine without double counting;
- internal transfers never become revenue/expense;
- historical invoice aggregate-only coverage remains explicit;
- full-period 2013 reader loads;
- monthly groups have traceable source coverage;
- no new version is exposed until the audit suite and protected Flow/invoice regressions pass.

