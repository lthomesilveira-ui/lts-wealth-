# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-08-31 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before writing.

## Conduct
- Preserve every open financial/documentary/classification dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, valuation or reconciliation.
- Ask the user only when a real financial/classification/documentary decision is required.
- Test before asking user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Re-fetch before every write and never force branch divergence.

## Release state
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- v143 integrated by normal PR #6; integrated baseline main SHA `0526033f33ef90086388a946470313bd5002180c`.
- Candidate-smoke `33401135988` SUCCESS and Pages `33401135026` SUCCESS on that same integrated SHA.
- Active implementation branch remains `v143-life-real-feedback` at `1b8a2246f9f9af77015caedf9975aef12f4d384f` for provenance; implementation code freeze is `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- `homologacao-current.json` is switched from v142 to v143 in the current exposure package; post-switch same-SHA candidate-smoke + Pages are still required before user action.
- Latest immutable checkpoints: `backups/WIP35_V143_PREINTEGRATION_CHECKPOINT_2026-08-31.md` and `backups/WIP35_V143_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-08-31.md`.
- Authenticated visual E2E: not performed / not claimed.

## v143 P0 package
- Dashboard header: `Sua vida financeira, em uma tela.`
- Hero: `Disponível realizável até D+3`; separate FGTS-inclusive reading explicitly restricted/D+30, not cash today.
- Future liquidity problem high with human cross-zero wording and request-by deadline.
- `Fatura vencida / a confirmar` restored.
- Planejamento visual label `Liquidez detalhada`; resource order bank cash → D0/Cofrinho → vested RSU → future vestings when actually available → FGTS D+30; Jan/2027 explained as management point, not proven insolvency.
- Atualizações action-first; classification evidence order explicit user rule → exact consistent LTS history → public merchant research → manual review.
- `GULA GULA MORUMBI`: two Aeternum Sep/2026 rows, total R$725,46, remains taxonomy_review despite public restaurant evidence; no invented final classification.
- Generic recurrence audit compares history against next 12 months; no hardcoded example list and no historical median auto-projection.
- Despesas human context + clickable composition; Cartões classification consolidation/raw evidence/Cartão × mês; Patrimônio vested RSU/future vestings/read-only anticipation/CIPÓ/Volvo.
- Deterministic v143 ownership redirects inherited v142 owners; runtime/navigation smoke desktop/mobile PASS; button census 197/197.

## Financial evidence that must not change by assumption
- Planning management point 08/01/2027; FGTS request-by 09/12/2026.
- FGTS documentary 18/08/2026 R$17.509,05; existing accrual model R$3.700/month; request-date projection R$32.309,05.
- Worst before contingency R$-21.046,80; worst after planned FGTS R$+11.262,25; no uncovered gap through 28/02/2027.
- Correct interpretation: liquidity-management point covered by already-modeled D+30 contingency if initiated on time; not proven patrimonial insufficiency.
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Historical card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap explicit; never fabricate.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle.
- Historical RSU sale 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unitemized.
- Volvo financing Bradesco: 60 × R$2.886,43, 08/09/2026 through 08/08/2031; no duplicate economic effect.
- Historical FGTS realization R$25.585,03 on 07/05/2026 and later current employer FGTS R$17.509,05 are different temporal positions.
- Bank↔liquidity-asset movements have economic effect zero and are excluded from spend/revenue.

## Final backend evidence
Fingerprint `85a1b60816a5b84dfe3b41341ed27948` unchanged before/after:
- v14 293 / 24 PASS;
- v15 67 / 5 PASS;
- v16 19 / 2 PASS;
- v17 32 / 4 PASS;
- staged total 411 checks / 35 suites PASS, not a single monolithic gate;
- supplemental v143 read-model QA v2 16/16 PASS.

## Open backlog that must survive every handoff
- Mastercard historical recovery: 2022 remaining months; 2023 12 ledger-only payments R$496.689,05 with independent category matrix absent; 2024 only Mar/May/Aug/Sep/Oct/Dec certified; 2025 Mar/Apr/May/Jun/Aug/Nov certified, Jan/Feb/Jul/Oct partial, Sep/Dec blocked.
- Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite 2025 12/12 certified.
- CIPÓ: consortium delta R$303,60; R$6.654,50 = R$6.502,70 + R$151,80 arithmetic overlap only with differing dates; condominium formula/cut unresolved; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70; no fabricated post-2029 TR.
- Human classification where evidence is insufficient.
- Guided document association UI.
- Liquidity cancellation/reversal append-only semantics and real authenticated save→refresh→visible-result inspection.
- Volvo exact trim/km before valuation refinement.
- Open Finance provider/pricing/SLA/bank coverage; no consent/spend/credential without explicit user decision.
- Performance only after correctness/exact parity.
- Real authenticated visual E2E.
- User material v143 homologation.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. Re-fetch manifest-switch main SHA.
2. Verify candidate-smoke + Pages on that same SHA and that the fixed manifest resolves v143.
3. Verify protected `index.html` blob unchanged.
4. If practical, add deployed fixed-link unauthenticated smoke without overstating it as authenticated E2E.
5. Only after gates are green say `AÇÃO SUA NECESSÁRIA` and request material visual homologation at the fixed link.
6. Do not promote public root without explicit user approval.
