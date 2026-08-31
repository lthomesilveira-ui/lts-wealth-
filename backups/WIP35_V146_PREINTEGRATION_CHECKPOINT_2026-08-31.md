# LTS Wealth — WIP35 v146 Pre-integration Checkpoint

Checkpoint date: 2026-08-31

## Purpose
Freeze the exact technical evidence for v146 before integration into `main`. This checkpoint does not switch fixed homologation, does not promote public `index.html`, does not alter financial rules/data/writers, and does not claim authenticated visual E2E.

## Current release baseline
- `main` before integration: `00771b92b1282c68654debb13cc0457ab69de038`.
- Public fallback: WIP35-v136 in protected `index.html`, exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation remains v145 via `wip35-v145-candidate.html`.
- v145 exposure SHA: `a99483543f3d1408be5b297dc66ec5f491be68dd`.
- Promotion status remains `not_promoted`.

## v146 candidate
- Branch: `v146-updates-navigation-stability`.
- Exact green candidate SHA: `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- Candidate tree: `6127163c146b3aa19b0af15a1b1198b872a23664`.
- Exact branch workflow: `33443494728` — SUCCESS.
- Evidence artifact: `9777202035`, name `wip35-v146-updates-navigation`, digest `sha256:90ceba82c969a4f7a13924120fdcbd89a66e3de91d530226303a6b71d6860ee1`.

## Regression reproduced
The v146 physical-navigation gate repeatedly failed on the transition from `Cartões` to `Patrimônio`. Playwright resolved a visible/stable Patrimônio button and began the physical click action, but the action could time out before returning. Other preceding destinations remained healthy, which narrowed the problem to inherited Patrimônio behavior rather than generic button wiring.

## Root cause and final correction
Several competing symptoms were removed during diagnosis, but the decisive remaining issue was inherited v142 wealth loading behavior:
- v142 kept legacy wealth ownership/loading beneath newer layers;
- v146 redirects the v142 wealth owner to the active v143 Patrimônio renderer and retires the redundant legacy loader;
- a stale/already-running v142 loader completion could still call `render()` after retirement, re-entering Patrimônio and sustaining an effective retry/render loop;
- final v146 guard suppresses that stale completion-triggered render once legacy wealth loading/ownership has been retired.

The v146 navigation owner also:
- keeps one stable seven-node navigation DOM instead of recreating nodes;
- captures navigation deterministically;
- coalesces/defer state/render work outside the synchronous physical-click path;
- preserves v143 active renderers and v145 Dashboard stability.

No financial rule, amount, classification, backend writer, RPC contract or economic effect was changed by this package.

## Exact green evidence
Run `33443494728` on SHA `bef91e27927dc8b73f89239568dd0ae81cd68707` completed SUCCESS and passed:
1. v146 architecture/static validation;
2. inherited button wiring census;
3. inherited v142 parser/static candidate gate;
4. inherited v142 browser smoke;
5. inherited v143 runtime/navigation smoke;
6. v146 classification + repeated-navigation smoke;
7. evidence artifact upload.

Repeated navigation executes **10 cycles × 7 destinations × 2 viewports = 140 physical Playwright clicks**. The order includes `Cartões` followed by `Patrimônio` in every cycle on desktop 1440×1000 and mobile 390×844.

The classification smoke also preserves the intended evidence model:
- Sal Gastronomia → `Restaurantes`, public research/confidence, manual-safe false;
- GULA GULA MORUMBI → `Restaurantes` suggestion/evidence, remains taxonomy/manual review;
- Superia Park → `Estacionamento E Pedágio` from consistent LTS history evidence;
- Floracea → `Farmácia` from public research;
- ZigPay/intermediator → no purchase category without final-purpose evidence.

This is synthetic/unauthenticated browser composition/runtime evidence. It is **not authenticated visual E2E** and executes no backend financial write.

## Financial/backend invariants explicitly retained
- Planning: first management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS 18/08/2026 R$17.509,05; existing accrual R$3.700/month; request-date projection R$32.309,05; worst before contingency -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027.
- Despesas economic invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card historical certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 detail gap remains explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle; historical sale difference R$578,68 remains unitemized.
- Volvo Bradesco financing remains 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, with no duplicate economic effect.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS; supplemental v143 QA 16/16 PASS.

## Open blockers carried forward
- Real authenticated visual E2E remains pending/unclaimed.
- Guided document association and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics.
- Mastercard/Visa documentary gaps; no inferred purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps and no fabricated post-2029 TR.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential without explicit user decision.
- Human classifications where evidence remains insufficient.
- Public `index.html` promotion only after explicit user approval.

## Required next gates
1. Create the documentation-only freeze commit on top of this exact candidate.
2. Re-fetch `main` and branch after the freeze and compare; proceed only if branch is strictly ahead and zero behind.
3. Fast-forward `main` with `force=false`; never merge by force.
4. Require same-SHA integrated-main v146 workflow SUCCESS, legacy candidate-smoke SUCCESS, Pages SUCCESS and inspect any additional relevant run.
5. Verify public `index.html` blob remains protected and `homologacao-current.json` still targets v145.
6. Only then prepare a separate v146 homologation exposure checkpoint/manifest switch, keeping promotion `not_promoted`.
7. Require exact exposure-SHA gates green before asking the user to test.
