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
