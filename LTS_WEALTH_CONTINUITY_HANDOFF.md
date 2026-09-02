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
- v146 has been integrated into `main` at `a2bfb254144efccb3da52d8e8fdc15a5c4182235` after a zero-divergence fast-forward.
- Integrated-main v146 run `33444432578` SUCCESS; Pages `33444431699` SUCCESS.
- Controlled fixed-homologation exposure is switching manifest to version v146, path `wip35-v146-candidate.html`, candidate head `bef91e27927dc8b73f89239568dd0ae81cd68707`, promotion `not_promoted`.
- v145 remains the immediately prior homologation rollback reference.
- Authenticated visual E2E: not performed / not claimed.

## v146 navigation/Patrimônio stability correction
Symptom reproduced by the product gate: repeated physical navigation could hang when moving from `Cartões` to `Patrimônio`; Playwright reached the physical click action but it could fail to return.

Final proven cause/correction:
- inherited v142 wealth loading/ownership survived beneath the newer candidate layers;
- v146 redirects Patrimônio ownership to the v143 renderer and retires the legacy v142 wealth loader;
- an already-running/stale v142 wealth-loader completion could still call `render()` after that retirement and re-enter the active Patrimônio path, sustaining an effective retry/render loop;
- v146 suppresses that stale completion render once the legacy loader/owner is retired;
- stable nav nodes are preserved and navigation state/render work is coalesced outside the synchronous click path;
- no financial rule, amount, classification, backend writer or economic effect changed.

Evidence:
- exact product SHA `bef91e27927dc8b73f89239568dd0ae81cd68707`;
- branch workflow `33443494728` SUCCESS, artifact `9777202035`;
- pre-integration/integrated SHA `a2bfb254144efccb3da52d8e8fdc15a5c4182235`;
- integrated-main workflow `33444432578` SUCCESS;
- integrated-main Pages `33444431699` SUCCESS;
- architecture/static + button census PASS;
- v142 parser/browser PASS;
- v143 runtime/navigation PASS;
- repeated navigation PASS: 10 cycles × 7 destinations × desktop/mobile = 140 physical clicks, including `Cartões` → `Patrimônio` every cycle.
The evidence is synthetic/unauthenticated browser evidence, not authenticated visual E2E.

## v145 Dashboard stability retained
- final renderer copy remains `Sua vida financeira, em uma tela.` / `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- repeated v142 Dashboard polling remains locked after valid cockpit data;
- explicit one-shot read-only refresh remains available;
- no financial/backend rule change.

## v144 Atualizações retained
- classification is first and compact, with suggestion + public/history evidence + confidence per item;
- evidence hierarchy remains explicit user rule → exact/consistent LTS history → public merchant research → manual confirmation;
- GULA GULA MORUMBI remains manual taxonomy review despite restaurant suggestion/evidence;
- marketplaces/intermediators remain review when purpose is not proven.

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
- Material v146 user homologation after exposure gates.
- Public `index.html` promotion only after explicit user approval.

## Immediate next execution
1. Commit controlled v146 fixed-homologation exposure with `promotion_status: not_promoted` and immutable exposure checkpoint.
2. On the exact exposure SHA require v146 workflow, legacy candidate-smoke and Pages SUCCESS.
3. Reconfirm protected public `index.html` exact blob and v146 manifest.
4. Only then tell the user `Pode acessar agora` and ask for material validation of repeated navigation, Patrimônio after Cartões, stable Dashboard and classification-first Atualizações.
5. Public root promotion remains separately blocked until explicit user authorization.


## Continuity update — v147 green before integration — 02/09/2026
- Branch `v147-guided-document-association`; green product SHA `8ae3eb92b1eb155ffdf029bbcb373fe1f3d3bace`.
- Run `33647189124` SUCCESS; artifact `9853344026`, digest `sha256:0d04050fee20cbafba3eb8dee9870785f271ebbbfc3e47d00bb0ed36f4e45ca2`.
- Guided document association passed desktop/mobile and all inherited gates, including v146 repeated navigation.
- Fixed homologation remains v146 and public `index.html` remains protected.
- Immediate execution: freeze docs, fast-forward main if strictly linear, exact integrated gates, then separate controlled v147 exposure.
- Backlog remains open for authenticated E2E, classification save→refresh/self-heal, liquidity save→refresh/reversal, documentary recovery, CIPÓ, Volvo and Open Finance decisions.


## Continuity update — v147 exposed for material homologation
- Exact exposure SHA `a4d6f49eded94d921de1ba9401d6a5a93ba653d2`; all six exact-SHA workflows SUCCESS.
- Fixed homologation manifest: v147 / `wip35-v147-candidate.html` / candidate `8ae3eb92…` / `not_promoted`.
- Public `index.html` remains blob `a130eafe…`.
- Checkpoint: `backups/WIP35_V147_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-09-02.md`.
- Next: user material homologation; continue autonomous backlog packages that do not require financial/classification decisions.
- Do not claim authenticated visual E2E; it remains open.
