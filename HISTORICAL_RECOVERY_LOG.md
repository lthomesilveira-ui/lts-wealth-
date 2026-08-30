# LTS Wealth — Historical Recovery Log

Purpose: persistent evidence/recovery log so historical reconstruction never depends on chat memory. This file records only evidence-backed state and never authorizes inferred classification, merchant, purchase, competence or reconciliation.

## Guardrails
- Historical cash ledger is never rewritten by category-allocation recovery.
- Historical category allocation is analytics-only.
- A cycle is certified only when complete signed category composition closes to the ledger to the cent and source identity is explicit.
- Payment/reference equality alone is insufficient for category certification.
- Signed credits/reversals remain documentary evidence; they are not silently normalized away.
- Mastercard Itaú evidence must come from `Cartão Itaú`; `Cartão Itaú VISA` / Visa Infinite is a distinct source.
- Retrieval failure is a technical blockage, never evidence absence.

## Canonical state — 2026-08-30
- Public fallback remains WIP35-v136; historical recovery has not changed the public build.
- Historical expense invariant: R$8,623,752.53.
- Effective expense cache: 3,767/3,767 rows exact.
- Recovered category-detail rows: 3,449.
- Certified historical category-allocation cycles: 34.
- Certified category-allocation rows: 553 / R$821,898.39.
- Aggregate fallback still distinct: 318 rows / R$2,714,803.16.
- Expense v9 19/19 PASS; Expense v10 18/18 PASS; core financial 15/15 PASS.
- Extended heavy gate v3: 213/213 PASS.
- Real authenticated visual E2E remains pending/unclaimed.

## Mastercard Itaú — 2025
### Certified exact
- 2025-03 — R$37,905.32; complete signed category matrix closes to `evento_base:2547`.
- 2025-04 — R$34,559.66; signed Crédito evidence closes the category matrix exactly.
- 2025-05 — R$28,105.02; exact matrix/ledger closure.
- 2025-06 — R$33,817.15; signed Crédito evidence closes exactly.
- 2025-08 — R$29,693.33; exact category matrix/ledger identity.
- 2025-11 — R$5,883.96; signed Crédito evidence closes exactly.

### Candidate partial — never certified until complete tail is recovered
- 2025-01 — source matrix R$38,636.48; ledger `evento_base:2414` R$38,635.88; signed Crédito -R$0.30 explains the R$0.60 sign-loss effect, but full category tail is missing.
- 2025-02 — source matrix R$37,939.80; ledger `evento_base:2487` R$37,939.80 exactly. Partial recovered categories extend through Espelhos/Box, but the tail is truncated. Never fill the remainder by arithmetic difference.
- 2025-07 — source matrix R$33,870.67; ledger `evento_base:2778` R$33,870.17; signed Crédito -R$0.25 explains the R$0.50 sign-loss effect. Previously recovered composition remains short by a tail; prior known unaccounted amount R$22.15. Full signed tail is required.
- 2025-10 — source matrix R$16,086.02; ledger `evento_base:2939` R$16,086.02 exactly; signed Crédito +R$0.03 exists. Recovered composition truncates after Projeto Automação and one documentary category line remains unidentified.

### Documentary-blocked
- 2025-09 — source matrix R$26,582.10 vs ledger `evento_base:2889` R$26,558.28; delta R$23.82. Signed Crédito -R$0.13 explains only R$0.26 of sign effect. Do not force.
- 2025-12 — source matrix R$14,062.17 vs ledger `evento_base:3041` R$13,195.37; delta R$866.80. Known signed Crédito is insufficient. Do not force.

## Mastercard Itaú — 2024
### Certified exact
- Mar, May, Aug, Sep, Oct, Dec.

### Settlement proven; category composition not recovered
All six source totals equal the canonical ledger payment to the cent, but exact payment identity alone does not authorize category allocation:
- 2024-01 — `evento_base:1829` R$53,652.87.
- 2024-02 — `evento_base:1871` R$58,667.61.
- 2024-04 — `evento_base:1966` R$47,802.70.
- 2024-06 — `evento_base:2061` R$48,393.80.
- 2024-07 — `evento_base:2104` R$51,947.18.
- 2024-11 — `evento_base:2281` R$45,259.24.

The repo search and `legacy_namespace` audit did not recover complete category matrices for these months. Keep them open until documentary composition is available.

## Historical validation registry
- Internal table `lts_card_historical_validation_registry` now persists the 12 open Mastercard 2024/2025 cycles.
- It stores validation evidence/status only; it is not a source for Despesas or category allocation.
- Browser roles cannot read the registry.
- `lts_card_historical_validation_registry_qa_v1`: 7/7 PASS.
- QA guarantees no registry month is present as `certified_exact` in `lts_card_historical_category_allocation`.
- Current registry: six 2024 settlement-proven/composition-missing; four 2025 candidate-partial; two 2025 documentary-blocked.

## Visa Infinite Itaú — 2025
- 12/12 months certified exact. Never mix this source with Mastercard Itaú evidence.

## C6 historical recovery
- Documentary target May/2024–Jun/2026 recovered except the Aug/2024 individual-detail gap R$66.70 in Táxi/Uber.
- Aug/2024 category total R$4,087.42 is certified; staged individual detail R$4,020.72. No missing purchase is invented.

## CIPÓ documentary linkage
- CIPÓ reconciliation remains separate from card-history analytics and consumption.
- 32 historical card aggregates remain `pending`; no aggregate was promoted by category-name matching.
- Source aggregate total R$1,465,713.29.
- Same-category recovered/certified evidence observed R$894,312.01.
- Conservative capped documentary floor R$569,196.83.
- 19/32 rubrics have some documentary coverage; 12 have enough same-category value to cover the aggregate amount but remain pending where instrument identity/composition is not proven.
- `lts_cipo_card_documentary_coverage_qa_v1`: 6/6 PASS and explicitly non-promoting.
- Consórcio Itaú R$303.60 and Condomínio formula/cut remain unresolved.

## Retrieval state
- File Library intermittently returned useful 2025 source material, then resumed failing before content retrieval.
- Latest targeted Jan/Feb/Jul/Oct searches failed at retrieval-service level.
- Repo search and database legacy staging/namespace do not contain the missing tails in recoverable text form.
- Do not repeatedly hammer retrieval in a short interval; retry later and only certify if complete signed composition is recovered.

## Next evidence work
1. Recover full signed tails for Mastercard Jan/Feb/Jul/Oct 2025; independently sum before any allocation insert.
2. Keep Sep/Dec 2025 blocked until the true reversal/adjustment evidence closes the ledger.
3. Recover complete category matrices for Mastercard Jan/Feb/Apr/Jun/Jul/Nov 2024; payment identity alone remains insufficient.
4. Continue older years only by documentary evidence and impact; do not backfill by pattern.
5. After every material exact recovery: rerun card-history coverage, Expense v9/v10, core financial regression and heavy homologation gate; update this log/backlog/checkpoint.
