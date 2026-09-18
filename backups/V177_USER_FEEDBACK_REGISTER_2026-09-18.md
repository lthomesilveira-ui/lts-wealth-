# V177 — Expense audit, drill-down and property UX feedback — 18/09/2026

Status: USER FEEDBACK REGISTERED / ONE PROPERTY-ROLLUP DECISION PENDING
Baseline: V176 fixed homologation
Public root: protected; no production promotion authorized

## F01 — Audit 2020 expense level critically
User observed:
- 2019 monthly average ≈ R$ 53.911;
- 2020 monthly average ≈ R$ 23 mil;
- the drop looks suspicious and requires a source audit rather than an assumption that it is correct.

Preliminary live-source audit:
- 2019 total = R$ 646.933,25; monthly average = R$ 53.911,10.
- 2019 Casamento = R$ 344.846,71.
- 2019 excluding Casamento = R$ 302.086,54; normalized monthly average = R$ 25.173,88.
- 2020 total = R$ 281.377,71; monthly average = R$ 23.448,14.
- Therefore most of the apparent 2019→2020 collapse is explained by the non-recurring wedding spend. Normalized 2019 excluding Casamento is only ~R$ 20,7 mil above 2020 total for the year.
- 2019 card aggregate = R$ 244.128,52 (Mastercard Itaú R$ 164.402,94 + Visa R$ 79.725,58).
- 2020 card aggregate = R$ 99.107,08, with Mastercard Itaú present in all 12 months and no Visa cash-settlement event in 2020.
- No 2020 month is entirely missing from the card-cash evidence, but the disappearance of Visa and the lower Mastercard spend remain audit points.
- Do not mark 2020 fully certified until source completeness/card history is checked against preserved workbook evidence.

## F02 — Remove audit/programming language from product front-end
User explicitly does not want technical reconciliation/programming explanations in the professional application UI.

Remove from the front-end:
- `fonte reconciliada` badge;
- original-planilha / duplicate / reconciliation strip;
- implementation rules, source-contract language or programming explanations.

Preserve all evidence in backend/checkpoints/audit receipts.

## F03 — Property / apartment management hierarchy
Current presentation fragments the apartment into:
- financing;
- acquisition/history;
- works/reform;
- recurring property expenses.

User wants a coherent management view of how much cash has gone into the apartment, but acquisition and financing must remain distinct concepts.

Proposed hierarchy pending one user decision:
- top-level rollup: `Apartamento · CIPÓ 396`;
- subgroups:
  1. Aquisição do imóvel;
  2. Financiamento imobiliário;
  3. Obra e reforma;
  4. potentially a separate `Custos recorrentes do imóvel` section (Condomínio, IPTU, Energia), depending on user confirmation.

Do not collapse acquisition into financing. Do not label financing payments as acquisition.

## F04 — Management-group transaction drill-down
User wants to click a management-group amount (example: Família — saídas R$ ~263 mil) and see exactly what composes it.

Required detail:
- one row per economic expense transaction;
- date;
- description/history;
- account or card/source;
- optional counterparty / center where useful;
- value;
- ordered clearly;
- must reconcile exactly to the selected management-group total;
- apply generically to all meaningful groups, not only Família.

A professional drawer/inline detail is preferred over exposing technical source diagnostics.

## F05 — Front-end principle
The product surface must answer management questions, not explain internal reconciliation mechanics. Reconciliation evidence is essential but belongs outside the normal front-end unless the user explicitly opens an audit/debug surface.
