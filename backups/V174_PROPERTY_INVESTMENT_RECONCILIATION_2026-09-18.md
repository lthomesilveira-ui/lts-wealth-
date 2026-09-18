# V174 — Property investment / works reconciliation — 18/09/2026

Status: INVESTIGATION COMPLETE; IMPLEMENTATION NOT YET APPLIED
Baseline: V173 fixed homologation
Source: private Supabase reconciliation + user-provided workbook photo
Public root: unchanged / protected

## User-reported mismatch
V173 full-period `Investimentos no imóvel — obra e reforma`: R$ 1.517.643,79.
Workbook summary `Outros / Reformas & Melhorias`: R$ 2.177.714,78.
Visible residual: R$ 660.070,99.

## Existing private source reconciliation already present
`lts_cipo_reconciliation_v4` is the current source reconciliation contract. It confirms:
- workbook historical basis `Reformas & Melhorias`: R$ 2.177.714,78;
- 42 improvement detail rows loaded from the workbook: R$ 2.174.777,52;
- internal workbook delta: R$ 2.937,26;
- cause: confirmed duplicate source row `conta corrente · Móveis · Móveis - O Parque` of R$ 2.937,26;
- financial treatment: `do_not_duplicate_ledger_or_cost_from_source_duplicate`;
- source summary for Móveis: R$ 94.744,98;
- loaded unique Móveis total: R$ 91.807,72;
- ledger Móveis current-account row: R$ 2.937,26.

Therefore the workbook summary value must remain preserved as source evidence, but must not be copied blindly into the reconciled economic ledger.

## Why V173 shows only R$ 1.517.643,79
The V171/V173 expense management reader is built from `lts_expense_effective_read_cache`; it does not consume all historical workbook-only CIPÓ card aggregates.

Current group composition:
- `Obra e Reforma` / account-ledger rows: R$ 705.851,96;
- `Cipó 396` currently mapped into the same management group: R$ 288.747,56;
- recovered/detailed historical card rows currently represented in the expense cache: R$ 523.044,27;
- total: R$ 1.517.643,79.

The `Cipó 396` R$ 288.747,56 is not equivalent to renovation spend:
- R$ 208.722,95 comes from `Cartório e Registro - O Parque` in 2022;
- R$ 80.024,61 is older historical `Cipó 396` evidence.
These rows should not be used merely to make the works/reform total larger.

## Historical-card coverage gap
The workbook contains 32 historical card aggregate improvement components totaling R$ 1.465.713,29:
- Mastercard: R$ 1.018.862,04;
- Visa Bradesco: R$ 172.145,10;
- Visa Infinite: R$ 274.706,15.

The current expense cache represents only R$ 523.044,27 of these improvement rubrics at detailed/recovered level.
The exact historical-card source coverage gap is R$ 942.669,02.

Largest source-vs-cache gaps by rubric:
- Projeto Arquitetura - O Parque: R$ 225.000,00;
- Marcenaria e Projeto - O Parque: R$ 121.000,00;
- Revestimento - O Parque: R$ 92.862,76;
- Eletrodomésticos - O Parque: R$ 79.804,33;
- Material Obra - O Parque: R$ 74.669,76;
- Projeto Iluminação - O Parque: R$ 59.839,94;
- Projeto Automação - O Parque: R$ 55.748,56;
- Projeto Final Executivo - O Parque: R$ 52.500,00;
- Envidraçamento - O Parque: R$ 49.583,59;
- Móveis - O Parque: R$ 37.387,11;
- Ar-condicionado - O Parque: R$ 36.880,98;
- remaining smaller rubrics complete the exact R$ 942.669,02 gap.

## Property ledger detail that is currently outside the works group
A unique current-account `Móveis - O Parque` economic occurrence of R$ 2.937,26 is presently presented under `Móveis e Decoração`, not under the property works/reform management group. It is also the source row duplicated in the original workbook formula. The reconciled system must count the economic occurrence once, never twice.

## Conclusion
The user is correct that the current V173 number is not an adequate full-period reconciliation of the property works/reform source.

However, the correct correction is NOT to hardcode R$ 2.177.714,78:
- that workbook summary contains a confirmed duplicated R$ 2.937,26 source row;
- the private reconciliation already records the guardrail not to duplicate that economic occurrence.

The successor should expose a source-reconciled property improvement view that:
1. keeps purchase/acquisition, financing and recurring property costs separate;
2. excludes the generic `Cipó 396` acquisition/history rows from works/reform;
3. includes the workbook-only historical card aggregate evidence without inventing individual purchases or double counting recovered rows;
4. counts the R$ 2.937,26 Móveis economic occurrence once;
5. preserves the original workbook R$ 2.177.714,78 as source evidence;
6. presents the reconciled unique-evidence value separately and explains the R$ 2.937,26 duplicate-source delta;
7. never fabricates dates/merchants for aggregate-only card evidence.

No financial source row has been changed by this investigation.
