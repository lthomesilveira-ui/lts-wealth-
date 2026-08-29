# LTS Wealth — Historical Recovery Log

Purpose: persistent recovery/evidence log so historical reconstruction does not depend on chat memory. This file records only evidence-backed state. It does not authorize financial assumptions or inferred classifications.

## Guardrails
- Historical cash ledger is never rewritten by category-allocation recovery.
- Historical category allocation is analytics-only.
- A cycle is certified only when signed category composition closes to the ledger to the cent and source identity is explicit.
- No purchase, merchant, market value, competence rule or financial classification is invented.
- If source evidence is incomplete, the cycle remains blocked.
- Mastercard Itaú evidence must come from `Cartão Itaú`; `Cartão Itaú VISA` is a separate source and must never be mixed.

## Canonical state — 2026-08-29
- Public baseline/fallback: WIP35-v136. No new public build from this recovery batch.
- Historical expense total: R$ 8,623,752.53, invariant after category recovery.
- Certified historical category-allocation cycles: 33.
- Expense v9 QA: 19/19 PASS, 33/33 certified cycles close.
- Expense v10 QA: 18/18 PASS.
- Core financial regression: 15/15 PASS.
- Projection bridge: PASS; max absolute residue approximately R$ 0.0193, below R$ 0.03 tolerance.
- Operational cache health: PASS/green.
- Real authenticated visual E2E: pending/unclaimed.

## Mastercard Itaú — 2025
### Certified
- 2025-04 — R$ 34,559.66. Legacy category matrix absolute total R$ 34,560.02; original `Cartão Itaú` signed Crédito = -R$0.18. Signed category sum closes exactly. No purchase/merchant invented.
- 2025-05 — R$ 28,105.02. Legacy matrix closes exactly to ledger.
- 2025-06 — R$ 33,817.15. Legacy category matrix absolute total R$ 33,818.05; original signed Crédito = -R$0.45. Signed category sum closes exactly.
- 2025-08 — certified exact from legacy category matrix/ledger identity already present in database.
- 2025-11 — R$ 5,883.96. Legacy matrix total R$ 5,883.98 had Crédito displayed as +R$0.01; original `Cartão Itaú` signed Crédito = -R$0.01. Signed category sum closes exactly. 20 nonzero category rows persisted. No purchase/merchant invented.

### Candidate but not yet certified
- 2025-01 — legacy `Cartão Itaú` matrix total R$ 38,636.48; ledger R$ 38,635.88; original signed Crédito series maps to -R$0.30, which explains the R$0.60 sign-loss difference. Still blocked until full category list is recovered and independently summed.
- 2025-02 — legacy matrix total R$ 37,939.80 equals ledger; original signed Crédito = 0. Still blocked until full category list is recovered and independently summed.
- 2025-03 — legacy matrix total R$ 37,905.32 equals ledger; original signed Crédito = 0. Still blocked until full category list is recovered and independently summed.
- 2025-07 — legacy matrix total R$ 33,870.67; ledger R$ 33,870.17; original signed Crédito = -R$0.25, consistent with a R$0.50 sign-loss difference. Still blocked until the entire category tail and counts are recovered.
- 2025-10 — legacy matrix total R$ 16,086.02 equals ledger; original signed Crédito = +R$0.03. Still blocked until the full category list is recovered and independently summed.

### Blocked by unexplained signed/reversal delta
- 2025-09 — legacy matrix R$ 26,582.10 versus ledger R$ 26,558.28. Signed Crédito -R$0.13 explains only R$0.26 of the difference; another signed reversal/adjustment remains unidentified. Do not force.
- 2025-12 — legacy matrix R$ 14,062.17 versus ledger R$ 13,195.37. Signed Crédito alone does not explain the R$866.80 gap. Do not force.

## Visa Infinite Itaú — 2025
- 12/12 months certified exact in database, with signed evidence retained where reversals/credits exist.

## C6 historical card recovery
- Documentary target May/2024–Jun/2026 recovered except Aug/2024 individual-detail gap R$66.70 in Táxi/Uber.
- Aug/2024 category total is certified; no sixth line is invented.

## CIPÓ / Patrimônio / Planejamento guardrails still active
- CIPÓ reconciliation remains separate from Despesas consumption; Consórcio is patrimonial contribution/investment, not consumption.
- CIPÓ current documentary debt R$1,779,905.50; market center R$5.2m with analytical range R$4.6–5.8m.
- Volvo current documentary financed balance R$110,492.81; future installments must not be treated as current debt.
- Planning first real gap remains 08/01/2027 under current evidence; FGTS R$17,509.05 is D+30 contingency, not immediate liquidity.

## Next evidence work
1. Recover complete 2025 Mastercard category tails for Jan/Feb/Mar/Jul/Oct and independently sum before any insert.
2. Keep Sep/Dec blocked until true signed reversals are identified.
3. Rerun v9/v10/core regression/projection bridge/operational health after every material insert batch.
4. Then continue Mastercard Itaú 2024 pending months, followed by 2023, by evidence/impact.
5. Update this log and `PROJECT_MASTER_BACKLOG.md` after every material recovery batch.
