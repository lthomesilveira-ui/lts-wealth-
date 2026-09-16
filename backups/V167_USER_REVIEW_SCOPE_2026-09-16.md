# LTS Wealth — V167 user review scope

Business date: 16/09/2026.

This scope is additive to the immutable V165/V166 checkpoints. V166 product head `117c467a02641c1b7e167493fda6f916e7927e14` and documentation head `9ec85db491c85c364c2ace135c09d1eea211990e` remain preserved.

## User-reported corrections and new requirements
1. Atualizações statement actions must open the guided upload for the named bank instead of populating transaction search.
2. Recurrence/planning audit must cover future years through 2030 and explicitly detect missing salary, card, tax and recurring-expense projections using historical evidence; no inferred item may write before confirmation.
3. Search actions must navigate to the exact Flow year/date, expand the matching day and open the matching projected event editor when editable.
4. Restore reviewed natural-language input for Pix, card purchase and bank transfer. Interpretation is a proposal; classification and financial posting require explicit confirmation.
5. Rebuild Despesas as a reliable analytical surface: every period control changes the full report, totals/charts remain consistent and the period is explicit.
6. Improve Bens e dívidas layout and replace raw identifiers/technical copy with user-facing names.
7. Every financing/loan needs detail: paid and future installments, outstanding balance, progress, next payments and payoff-now versus contractual-total comparison when the source supports it.
8. CIPÓ 396 must expose the mortgage statement/schedule as well as documented purchase and works spending.
9. Dashboard liquidity chart must clearly show the zero axis and distinct base, vesting and FGTS series/legend.
10. Re-audit daily historical Flow from 10/10/2013 and reject impossible opening/closing balances such as the reported 2021–2023 multi-million values.
11. Bradesco R$29.90 invoice item must be classified as Assinaturas and shown in reconciled invoice detail.
12. RSU surface needs a consolidated award total while preserving vested shares, Cash RSU and brokerage cash as distinct layers.
13. Patrimônio and Dashboard distribution must include all documented assets: CIPÓ, Volvo, RSUs, Schiavalli and pension balances, with a visible as-of date near every balance.
14. Add Novartis and Organon pensions as restricted assets after the user supplies their current balances/evidence; both use a regressive tax regime and must not be presented as immediately equivalent to cash.
15. Dashboard bank-cash/current-account value must use today's Flow position and `O que vem pela frente` must use current, actionable commitments.
16. Open Finance remains an explicit backlog item with provider/status/dependencies; do not imply banks are connected before an authorized provider integration exists.

## Already confirmed in V166
- Paid September invoice tasks were removed from Atualizações.
- RSU action price and USD/BRL assumption are editable.
- 14/09/2026 Flow arithmetic was confirmed by the user.

## Inputs received after scope capture
- Organon Multiprev position dated 04/09/2026: gross balance and participant/sponsor composition applied to the private authenticated data layer. Exact values are intentionally not duplicated in this repository.
- Novartis Previ Plano D position dated 01/08/2026: gross balance applied to the private authenticated data layer; the screenshot does not expose a complete participant balance, so that field remains blank. Exact values are intentionally not duplicated in this repository.
- Both positions are regressive-tax retirement assets and remain restricted/gross; no net redemption value is inferred.

## Deferred user review
- The user's voice note ended mid-sentence after `O que vem pela frente...`; V167 implements the evidenced current commitments and leaves room for the next review instead of inventing the missing request.

## Safety and truth boundaries
- Never invent an installment, historic balance, category, valuation, tax outcome or Open Finance connection.
- Historical facts stay append-only; corrections are audited adjustments.
- Public `index.html` remains protected; V167 is homologation only until explicit promotion approval.
