# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation is switching to **v146** via `wip35-v146-candidate.html` in the controlled exposure commit.
- Manifest candidate head: `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- Promotion status remains `not_promoted`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v146 integrated evidence
- Exact green product SHA: `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- Branch workflow `33443494728`: SUCCESS; artifact `9777202035`.
- Pre-integration freeze/integrated SHA: `a2bfb254144efccb3da52d8e8fdc15a5c4182235`.
- Integrated-main v146 workflow `33444432578`: SUCCESS.
- Integrated-main Pages `33444431699`: SUCCESS.
- `candidate-smoke` did not auto-trigger at integration because its path filter excludes v146 files. The v146 workflow itself reran inherited candidate parser/browser gates; the exposure commit modifies `homologacao-current.json`, which is in the legacy candidate-smoke path filter and therefore must trigger it on the exact exposure SHA.

## v146 correction
Repeated physical navigation testing reproduced a hang specifically around `Cartões` → `Patrimônio`. The final cause was inherited v142 wealth-loader completion/retry behavior, not a financial/data rule. A stale completion could call `render()` after v146 had retired legacy wealth loading/ownership, re-entering Patrimônio and sustaining an effective retry/render loop.

v146:
- keeps one stable seven-button nav DOM without node recreation;
- coalesces/defer state/render work outside the synchronous physical-click path;
- redirects the v142 wealth owner to the active v143 Patrimônio renderer;
- retires the redundant legacy v142 wealth loader;
- suppresses stale v142 wealth-loader completion render after retirement;
- preserves v144 Atualizações evidence/confidence/classification surface and v145 Dashboard stability;
- changes no financial rule, value, classification, backend writer or economic effect.

## Repeated-navigation evidence
The v146 smoke performs 10 cycles over seven destinations on desktop and mobile: **140 physical Playwright clicks**, including `Cartões` → `Patrimônio` every cycle. Both branch and integrated-main v146 runs passed. This is synthetic/unauthenticated browser evidence, not authenticated visual E2E, and performs no backend financial write.

Classification evidence remains conservative: GULA GULA MORUMBI may show `Restaurantes` with research/confidence but remains manual taxonomy review; marketplaces/intermediators remain unresolved without purpose evidence.

## Financial/backend invariants — unchanged
- Planning: management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; existing accrual R$3.700/mês; request-date FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027.
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle; R$578,68 historical sale difference remains unitemized.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031, no duplicate economic effect.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS plus supplemental 16/16.

## Open blockers retained
- Human classification where evidence remains insufficient.
- Guided document association and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics.
- Mastercard/Visa documentary gaps; never infer purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps; no fabricated post-2029 TR.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend without explicit decision.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.

## Current gate to advance
1. Commit the controlled v146 exposure: manifest v146 / `wip35-v146-candidate.html`, candidate head `bef91e279…`, `promotion_status: not_promoted`, plus immutable exposure checkpoint and canonical docs.
2. On that exact exposure SHA require all of:
   - v146 navigation/classification workflow SUCCESS;
   - legacy `candidate-smoke` SUCCESS;
   - Pages SUCCESS;
   - protected `index.html` blob exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
   - manifest resolves v146 / `wip35-v146-candidate.html` / candidate `bef91e279…` / `not_promoted`.
3. Only after all exact-SHA gates are green tell the user `Pode acessar agora` with the fixed homologation URL.
4. First material check: repeated navigation including `Cartões` → `Patrimônio`; Dashboard no flicker; Atualizações retains classification-first evidence/confidence/select/save surface.
5. Public root promotion remains a separate explicit user authorization.


## Current gate — v147 integration and controlled exposure — 02/09/2026
1. v147 product/gate SHA `8ae3eb92…` is green in run `33647189124`; checkpoint `backups/WIP35_V147_PREINTEGRATION_CHECKPOINT_2026-09-02.md`.
2. Confirm branch remains strictly ahead of main with no divergence, then fast-forward main without force.
3. On the exact integrated SHA require v147 workflow SUCCESS, legacy candidate-smoke SUCCESS, Pages SUCCESS and protected `index.html` blob `a130eafe…`.
4. In a separate commit expose manifest v147 / `wip35-v147-candidate.html` with `promotion_status: not_promoted`; rerun exact exposure gates.
5. Only after the served fixed homologation is verified may the user be told `Pode acessar agora`.
6. Public root promotion remains blocked pending explicit authorization.
