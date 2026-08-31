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
- Public fallback remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation currently targets **v144**; exposure SHA `e8c522728a9c5740be89f1bcf08c8301ceecee78`.
- v144 post-switch exact-SHA runs: Updates smoke `33417045276`, candidate-smoke `33417045163`, Pages `33417043749` — all SUCCESS.
- User material homologation then identified a separate Dashboard title flicker.
- Active corrective branch: `v145-dashboard-stability`.
- Current green v145 product head: `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`.
- v145 branch workflow `33421305585` SUCCESS; artifact `9769043340`.
- Authenticated visual E2E: not performed / not claimed.

## v145 Dashboard stability correction
User symptom: Dashboard headings visibly alternate like a bad contact.

Proven root cause:
- v142 Dashboard installer polls every 180 ms and repeatedly re-fetches/re-renders the cockpit;
- v143 Dashboard renderer reinstates older H1/subtitle;
- v143 feedback polish rewrites them every 220 ms to final copy;
- the competing cycles create flicker.

Implementation:
- candidate `wip35-v145-candidate.html` preserves the inherited v142/v143/v144 product chain;
- no historical candidate file is rewritten;
- stabilization marker `single-refresh-title-stable-v1`;
- stable renderer returns final copy directly: `Sua vida financeira, em uma tela.` / `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- v142 repeated Dashboard polling is locked only after valid cockpit data exists;
- explicit one-shot read-only cockpit refresh remains available through `LTS_V145_REFRESH_DASHBOARD`;
- no permanent v145 interval is introduced;
- v144 Atualizações action center remains inherited;
- technical `_tmp` introduced during branch prep is deleted from the v145 tree and never affected financial/product data.

Evidence from run `33421305585`, desktop and mobile:
- one and only one H1 value throughout temporal observation;
- one and only one subtitle value;
- `renderDelta=0`;
- `rpcDelta=0` for Dashboard cockpit;
- legacy poll guard true;
- v144 Atualizações classification root/suggestion/confidence preserved;
- inherited v142 parser/browser and v143 runtime/navigation PASS;
- button contract audit PASS;
- zero overflow and zero errors.
This is synthetic/unauthenticated browser evidence, not authenticated visual E2E.

## Financial evidence that must not change by assumption
- Planning management point 08/01/2027; FGTS request-by 09/12/2026.
- FGTS documentary 18/08/2026 R$17.509,05; existing accrual model R$3.700/month; request-date projection R$32.309,05.
- Worst before contingency -R$21.046,80; worst after planned FGTS +R$11.262,25; no uncovered gap through 28/02/2027.
- Correct interpretation: liquidity-management point covered by already-modeled D+30 contingency if initiated on time; not proven patrimonial insufficiency.
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Historical card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle.
- Historical RSU sale 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unitemized.
- Volvo financing Bradesco: 60 × R$2.886,43, 08/09/2026 through 08/08/2031; no duplicate economic effect.
- Historical FGTS realization R$25.585,03 on 07/05/2026 and later current employer FGTS R$17.509,05 are different temporal positions.
- Bank↔liquidity-asset movements have economic effect zero and are excluded from spend/revenue.

## Backend evidence inherited unchanged
Fingerprint `85a1b60816a5b84dfe3b41341ed27948`: v14 293/24, v15 67/5, v16 19/2, v17 32/4; staged total 411 checks / 35 suites PASS; supplemental v143 QA 16/16 PASS. v145 changes no backend financial rule or writer.

## Open backlog that must survive every handoff
- Mastercard historical recovery: 2022 remaining months; 2023 12 ledger-only payments R$496.689,05 with independent category matrix absent; 2024 only Mar/May/Aug/Sep/Oct/Dec certified; 2025 Mar/Apr/May/Jun/Aug/Nov certified, Jan/Feb/Jul/Oct partial, Sep/Dec blocked.
- Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- CIPÓ: consortium delta R$303,60; R$6.654,50 = R$6.502,70 + R$151,80 arithmetic overlap only with differing dates; condominium formula/cut unresolved; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70; no fabricated post-2029 TR.
- Human classification where evidence is insufficient.
- Guided document association UI and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Liquidity cancellation/reversal append-only semantics and real authenticated save→refresh→visible-result inspection.
- Volvo exact trim/km before valuation refinement.
- Open Finance provider/pricing/SLA/bank coverage; no consent/spend/credential without explicit user decision.
- Performance only after correctness/exact parity.
- Real authenticated visual E2E.
- Material user v145 homologation only after safe exposure gates.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. Commit v145 checkpoint + canonical docs on the green branch.
2. Integrate v145 into main with no force/divergence overwrite; keep homologation manifest on v144.
3. Require v145 workflow + Pages on exact integrated SHA; public index unchanged.
4. Separate exposure commit switches fixed homologation manifest to v145.
5. Require same-SHA post-switch v145 workflow + Pages; public index unchanged.
6. Only then ask the user to re-test Dashboard stability.
