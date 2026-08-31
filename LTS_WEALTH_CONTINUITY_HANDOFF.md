# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-08-31 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before writing.

## Conduct
- Preserve every open financial/documentary/classification dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, valuation or reconciliation.
- Ask user only when a real financial/classification/documentary decision is required.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Re-fetch before every write and never force branch divergence.

## Release state
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public fallback remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation now targets **v145**.
- Exposure SHA `a99483543f3d1408be5b297dc66ec5f491be68dd`.
- Manifest: version v145, path `wip35-v145-candidate.html`, candidate head `9d4a52df566d74bdc77f92b0d227906fc46bddce`, promotion `not_promoted`.
- Post-switch exact-SHA runs: v145 stability `33424045510`, v144 Updates `33424045367`, candidate-smoke `33424045318`, Pages `33424044022` — all SUCCESS.
- Authenticated visual E2E: not performed / not claimed.
- Material user v145 visual homologation is now pending.

## v145 Dashboard stability correction
User symptom: Dashboard headings visibly alternated like a bad contact.

Proven cause:
- v142 Dashboard polling could repeatedly refresh/re-render;
- v143 renderer returned older head copy;
- v143 feedback polish rewrote final copy on its own cycle;
- competing cycles caused flicker.

Implementation:
- preserves inherited v142/v143/v144 chain and historical candidates;
- marker `single-refresh-title-stable-v1`;
- final renderer copy is `Sua vida financeira, em uma tela.` / `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- repeated v142 Dashboard polling is locked after valid cockpit data;
- explicit one-shot read-only refresh remains available;
- no permanent new interval;
- v144 Atualizações action center remains inherited;
- no financial/backend rule change.

Evidence:
- product commit `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`;
- hardened SHA `9d4a52df566d74bdc77f92b0d227906fc46bddce`;
- branch run `33423228532` SUCCESS;
- integrated run `33423462471` SUCCESS, artifact `9769869448`;
- integrated Pages `33423461388` SUCCESS;
- exposure exact-SHA runs `33424045510`, `33424045367`, `33424045318`, `33424044022` all SUCCESS;
- temporal desktop/mobile: one title/subtitle, `renderDelta=0`, `rpcDelta=0`, zero overflow/errors;
- v144 Atualizações suggestion/evidence/confidence preserved.
This remains synthetic/unauthenticated browser evidence, not authenticated visual E2E.

## Financial evidence that must not change by assumption
- Planning management point 08/01/2027; FGTS request-by 09/12/2026.
- FGTS documentary 18/08/2026 R$17.509,05; existing accrual model R$3.700/month; request-date projection R$32.309,05.
- Worst before contingency -R$21.046,80; worst after planned FGTS +R$11.262,25; no uncovered gap through 28/02/2027.
- Correct interpretation: liquidity-management point covered by D+30 contingency if initiated on time; not proven patrimonial insufficiency.
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Historical card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle.
- Historical RSU sale 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unitemized.
- Volvo financing Bradesco: 60 × R$2.886,43, 08/09/2026 through 08/08/2031; no duplicate economic effect.
- Historical FGTS realization R$25.585,03 on 07/05/2026 and later employer FGTS R$17.509,05 are different temporal positions.
- Bank↔liquidity-asset movements have economic effect zero and are excluded from spend/revenue.

## Backend evidence inherited unchanged
Fingerprint `85a1b60816a5b84dfe3b41341ed27948`: v14 293/24, v15 67/5, v16 19/2, v17 32/4; staged total 411 checks / 35 suites PASS; supplemental v143 QA 16/16 PASS.

## Open backlog that must survive every handoff
- Mastercard: 2022 remaining months; 2023 12 ledger-only payments R$496.689,05 with independent category matrix absent; 2024 only Mar/May/Aug/Sep/Oct/Dec certified; 2025 Mar/Apr/May/Jun/Aug/Nov certified, Jan/Feb/Jul/Oct partial, Sep/Dec blocked.
- Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- C6 Aug/2024 explicit R$66,70 detail gap; never fabricate purchase.
- CIPÓ: consortium delta R$303,60; R$6.654,50 = R$6.502,70 + R$151,80 arithmetic overlap only with differing dates; condominium formula/cut unresolved; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70; no fabricated post-2029 TR.
- Human classification where evidence is insufficient.
- Guided document association UI and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Liquidity cancellation/reversal append-only semantics and authenticated save→refresh→visible-result inspection.
- Volvo exact trim/km before valuation refinement.
- Open Finance provider/pricing/SLA/product×bank coverage; no consent/spend/credential without explicit user decision.
- Performance only after correctness/exact parity.
- Real authenticated visual E2E.
- Material user v145 homologation.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. User checks v145 materially at the fixed homologation URL, first leaving Dashboard open long enough to detect any title flicker, then navigating once Dashboard ↔ Atualizações.
2. If user reports a material regression, reproduce and fix in a coherent new candidate package; keep public fallback untouched.
3. If user approves, do not promote public root until explicit authorization.
4. Continue autonomous open-backlog work that does not require user financial/documentary decisions.
