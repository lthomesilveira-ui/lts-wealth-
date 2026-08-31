# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Fixed homologation currently targets **v145** via `wip35-v145-candidate.html`.
- v145 exposure SHA: `a99483543f3d1408be5b297dc66ec5f491be68dd`.
- v145 manifest candidate head: `9d4a52df566d74bdc77f92b0d227906fc46bddce`.
- Promotion status: `not_promoted`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v146 pre-integration candidate
- Active branch: `v146-updates-navigation-stability`.
- Exact green product SHA: `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- Branch workflow `33443494728`: SUCCESS.
- Evidence artifact: `9777202035` (`wip35-v146-updates-navigation`).
- v146 is **not integrated into main and not exposed in fixed homologation** at this checkpoint.

### Why v146 exists
Repeated physical navigation testing reproduced a hang specifically around `Cartões` → `Patrimônio`. The final cause was not a financial/data rule. An inherited v142 wealth-loader completion/retry path could still call `render()` after v146 retired the legacy wealth loader/owner, allowing stale completion to re-enter the Patrimônio render path and create an effective retry/render loop.

### v146 correction
- Stable seven-button nav DOM; no nav-node recreation after ownership is locked.
- Navigation work is coalesced and moved outside the synchronous physical-click path.
- v142 wealth owner is redirected to the v143 Patrimônio renderer.
- Legacy v142 wealth loader is retired once v146 owns Patrimônio.
- Stale v142 wealth-loader completion render is suppressed after retirement so it cannot restart the loop.
- v144 Atualizações evidence/confidence/classification surface and v145 Dashboard stability remain inherited.
- No financial rule, value, classification, backend writer or economic effect changed.

## Exact v146 branch evidence
On `bef91e27927dc8b73f89239568dd0ae81cd68707`, run `33443494728` passed:
1. v146 architecture/static validation;
2. inherited button wiring census;
3. inherited v142 parser/static candidate gate;
4. inherited v142 browser smoke;
5. inherited v143 runtime/navigation smoke;
6. v146 classification + repeated-navigation smoke;
7. evidence artifact upload.

The v146 repeated-navigation smoke performs 10 cycles over seven destinations on desktop and mobile: **140 physical Playwright clicks**, including `Cartões` → `Patrimônio` every cycle. This is synthetic/unauthenticated browser evidence, not authenticated visual E2E, and performs no backend financial write.

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
1. Freeze v146 evidence/canonical docs without changing product, manifest or public fallback.
2. Re-fetch `main` and branch; require zero divergence and branch strictly ahead.
3. Integrate by normal fast-forward only (`force=false`).
4. On the exact integrated-main SHA require v146 workflow SUCCESS, legacy candidate-smoke SUCCESS and Pages SUCCESS; inspect any additional safety-relevant run fired by the commit.
5. Reconfirm protected `index.html` blob and v145 homologation manifest are unchanged.
6. Only then create a separate controlled exposure package that switches `homologacao-current.json` to v146 / `wip35-v146-candidate.html`, keeps `promotion_status: not_promoted`, creates an immutable exposure checkpoint and synchronizes canonical docs.
7. On the exact exposure SHA require v146 smoke, candidate-smoke and Pages SUCCESS before telling the user `Pode acessar agora`.
8. Public root promotion remains a separate explicit user authorization.
