# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-08-31 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before writing.

## Conduct
- Preserve every open financial/documentary/classification dependency; never compact it away.
- Project updates to the user use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, valuation or reconciliation.
- Ask the user only when a real financial/classification/documentary decision is required.
- Test before asking user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Re-fetch before every write and never force branch divergence.

## Release state at this checkpoint
- Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Homologation manifest still **v142**; do not expose v143 until integrated-main same-SHA candidate-smoke + Pages are green.
- Public `index.html` fallback remains WIP35-v136; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Main immediately before this docs package: `53b586b3feec95089d26cfc2cf797576131c2b50`.
- Active branch: `v143-life-real-feedback`.
- Frozen v143 implementation code head: `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- Immutable pre-integration checkpoint: `backups/WIP35_V143_PREINTEGRATION_CHECKPOINT_2026-08-31.md`.

## v143 package completed before integration
- `wip35-v143-candidate.html`: wrapper over v142; no public-root promotion.
- `wip35-v143-life-real.js`: Dashboard, Liquidez detalhada, Despesas drill-down, Cartão × mês, card detail, Patrimônio, RSU/vestings, read-only anticipation scenario, CIPÓ, Volvo and v143 nav.
- `wip35-v143-feedback-polish.js`: evidence-assisted classification, generic recurrence/future UI, detail focus, exact executive Dashboard wording/overdue card snapshot and Planning management-point explanation.
- `wip35-v143-ownership.js`: deterministic ownership by redirecting inherited v142 pointers instead of timer fighting.
- Feedback marker: `classification-evidence-recurrence-generic-decision-cockpit-v2`.
- Ownership marker: `redirect-inherited-owners-v2`.
- Branch candidate-smoke run `33399959217`: SUCCESS on code SHA `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- Desktop 1440×1000 PASS; mobile 390×844 PASS; zero overflow; zero errors.
- Runtime owners true for Dashboard/Planejamento/Despesas/Cartões/Patrimônio/nav; inherited pointers redirected; all main navigation clicks pass.
- Button census: 197/197 identifiable/wired, zero unresolved/anonymous.
- Not authenticated visual E2E.

## P0 product semantics preserved
### Dashboard
- Header: `Sua vida financeira, em uma tela.`
- Hero: `Disponível realizável até D+3`.
- Clear second balance if FGTS is also activated; FGTS explicitly restricted/D+30 and not cash today.
- Future negative point brought high in the page with human wording: without a liquidity action, cash crosses zero on the management date.
- If FGTS is the contingency, request-by date and D+30 timing are clear.
- Faturas vencidas/a confirmar, faturas abertas, operational work and next card action remain executive signals.
- Few numbers that decide; no QA-screen regression.

### Planejamento / Liquidez detalhada
- Resource order: bank cash → D0/Cofrinho → vested RSU → new vestings only when actually available → FGTS D+30.
- First management point 08/01/2027; FGTS request-by 09/12/2026.
- Documentary FGTS 18/08/2026 R$17.509,05; existing accrual model R$3.700/month; projected request-date balance R$32.309,05.
- Worst before contingency R$-21.046,80; worst after planned FGTS R$+11.262,25.
- Required interpretation: liquidity management point, not proven patrimonial insufficiency.
- Conditional vestings separated from already-available liquidity.

### Atualizações / classification / recurrence
- Action-first checklist remains primary.
- Evidence order: explicit user semantic rule → exact consistent LTS history → public merchant research → manual review.
- Public research may identify merchant/suggest category but never invent purchase purpose or auto-confirm ambiguous taxonomy.
- `GULA GULA MORUMBI` remains taxonomy_review despite public restaurant evidence; total R$725,46 in two Aeternum Sep/2026 rows.
- Recurrence audit is generic over history versus next 12 months; no hardcoded example series and no median-to-future auto projection.

### Despesas / Cartões / Patrimônio
- Despesas: human category/group/macrogroup/center-cost context with clickable real composition; mixed certified-detail/aggregate historical model retained.
- Cartões: card×month matrix, classification consolidation and raw evidence; open bill observed-now; future installments known contracted floor only.
- RSU vested: 459.483 units / R$32.772,30 / D+3; future awards excluded from current acquired wealth.
- Historical RSU sale: 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unitemized.
- CIPÓ drill-down preserves documentary debt/market/equity/history without calling market-minus-cost taxable gain.
- Volvo financing Bradesco: 60 × R$2.886,43, 08/09/2026 through 08/08/2031; Flow Bradesco and Patrimônio without duplicate effect.

## Final backend evidence before integration
Fingerprint before/after: `85a1b60816a5b84dfe3b41341ed27948`.
- v14 293 checks / 24 suites PASS.
- v15 67 / 5 PASS.
- v16 19 / 2 PASS.
- v17 32 / 4 PASS.
- Same-fingerprint staged total: 411 checks / 35 suites PASS; do not call it a single monolithic gate.
- Supplemental `lts_v143_life_real_backend_qa_v2`: 16/16 PASS on same fingerprint.
- Transactional liquidity QA rolls back every QA financial/cache mutation.

## Fixed financial/historical guardrails
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Historical card certified allocation 38 cycles / 650 rows / R$885.855,19.
- Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap remains explicit; never fabricate.
- FGTS historical R$25.585,03 realization on 07/05/2026 + same-day R$25.000 investment is a historical state, not the same as current employer FGTS R$17.509,05.
- Facts beat projections; scenarios never become facts; stale/superseded anchors never reanchor.
- Bank↔liquidity asset movement economic effect is zero and excluded from spend/revenue.

## Open backlog that must survive every handoff
- Mastercard historical recovery, especially 2022 remaining months and 2023 12 ledger-only payments R$496.689,05 with no independent category matrix.
- Visa 2017 R$126.681,76 aggregate-only and Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite 2025 certified 12/12.
- Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov, partial Jan/Feb/Jul/Oct, blocked Sep/Dec.
- CIPÓ consortium delta R$303,60; R$6.654,50 overlap arithmetic only; condominium formula/cut unresolved; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70; never fabricate post-2029 TR.
- Classification where evidence is insufficient.
- Guided document association UI with explicit identity/competence/as-of inputs.
- Liquidity cancellation/reversal append-only semantics and real authenticated save→refresh→visible-result inspection.
- Volvo exact trim/km before valuation refinement.
- Open Finance production provider/pricing/SLA/bank coverage; no consent/spend/credential without explicit user decision.
- Performance only after correctness/exact parity.
- Real authenticated visual E2E.
- User material v143 homologation.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. Re-fetch `main`, branch, backlog, gate, this handoff and v143 checkpoint.
2. Integrate v143 branch via normal merge/PR semantics; no force.
3. Verify candidate-smoke + Pages on the same integrated main SHA.
4. Verify protected `index.html` blob unchanged.
5. Only then switch `homologacao-current.json` v142→v143.
6. Verify fixed-link candidate-smoke + Pages on the manifest-switch main SHA.
7. Only after all above say `AÇÃO SUA NECESSÁRIA` and ask for material visual homologation through the fixed link.
8. Do not promote public root without explicit user approval.
