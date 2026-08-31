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
- v143 integrated by normal PR #6; integrated baseline `0526033f33ef90086388a946470313bd5002180c`.
- v143 exposure main SHA `a86b7cffe909098d65fcaad849800316c13dab3a`.
- v143 post-switch Pages `33402028275` SUCCESS and candidate-smoke `33402029074` SUCCESS on that exact exposure SHA.
- Fixed homologation currently targets v143.
- User material homologation found a P0 Atualizações regression; v144 is the corrective candidate and is not yet exposed.
- Active branch: `v144-updates-classification-layout`.
- Current green branch head: `f7cd162062406c2e1e37328883ca9586cc0374a8`.
- Latest v144 branch gate: `33412827358` SUCCESS.
- Authenticated visual E2E: not performed / not claimed.

## v144 corrective package
User feedback preserved:
- Atualizações must restore the earlier suggestion / research / certainty-% model.
- Layout must be compact and clearly hierarchical instead of loose cards/blank space.
- Classification should be first and actionable.

Implementation:
- candidate `wip35-v144-candidate.html`;
- deepest host marker `deep-runtime-host-v1`;
- lexical bridge marker `v144-lexical-state-bridge-v1`;
- Updates marker `classification-action-center-v2`;
- v144 outer marker is `v144`; deepest inherited runtime remains `v143` by design.
- preserves `cardClassificationUpdates` / `expenseClassificationUpdates` and old save controls.
- no direct backend financial writer added; does not replace `w.atualizacoes`.
- secondary recurrence/maintenance sections compact/collapsible; duplicated v143 evidence panel suppressed.

Run `33412827358` proves desktop + mobile:
- suggestion/evidence visible;
- 83% suggestion / 99% identification / 91% ambiguous-marketplace identification in synthetic evidence;
- 2 save controls preserved;
- classification before secondary sections;
- ownership for Dashboard/Planejamento/Despesas/Cartões/Patrimônio/nav remains true;
- all main nav click-throughs pass;
- zero overflow; zero errors.
This is unauthenticated browser composition/navigation evidence, not authenticated visual E2E.

## Financial evidence that must not change by assumption
- Planning management point 08/01/2027; FGTS request-by 09/12/2026.
- FGTS documentary 18/08/2026 R$17.509,05; existing accrual model R$3.700/month; request-date projection R$32.309,05.
- Worst before contingency -R$21.046,80; worst after planned FGTS +R$11.262,25; no uncovered gap through 28/02/2027.
- Correct interpretation: liquidity-management point covered by already-modeled D+30 contingency if initiated on time; not proven patrimonial insufficiency.
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Historical card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap explicit; never fabricate.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle.
- Historical RSU sale 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unitemized.
- Volvo financing Bradesco: 60 × R$2.886,43, 08/09/2026 through 08/08/2031; no duplicate economic effect.
- Historical FGTS realization R$25.585,03 on 07/05/2026 and later current employer FGTS R$17.509,05 are different temporal positions.
- Bank↔liquidity-asset movements have economic effect zero and are excluded from spend/revenue.

## Backend evidence inherited unchanged
Fingerprint `85a1b60816a5b84dfe3b41341ed27948`:
- v14 293 / 24 PASS;
- v15 67 / 5 PASS;
- v16 19 / 2 PASS;
- v17 32 / 4 PASS;
- staged total 411 checks / 35 suites PASS, not a single monolithic gate;
- supplemental v143 read-model QA v2 16/16 PASS.
v144 has no backend financial-rule change.

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
- Material user v144 homologation after safe exposure.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. Freeze v144 evidence and update canonical docs/checkpoint.
2. Extend the static button census to include v144 while keeping legacy candidate-smoke intact.
3. Require both branch workflows green.
4. Open/merge normal PR to main with expected head SHA.
5. Require v144 smoke + legacy candidate-smoke + Pages on exact integrated SHA; public index unchanged and homologation still v143.
6. Separate exposure commit switches fixed homologation manifest to v144.
7. Require same-SHA post-switch v144 smoke + candidate-smoke + Pages and public index unchanged.
8. Only then tell the user `Pode acessar` at the fixed homologation URL, starting with Atualizações.
9. Do not promote public root without explicit user approval.
