# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation URL: `homologacao.html`.
- Fixed homologation currently targets **v144**; v144 exposure SHA `e8c522728a9c5740be89f1bcf08c8301ceecee78`.
- v144 post-switch exact-SHA gates: Updates smoke `33417045276` SUCCESS; legacy candidate-smoke `33417045163` SUCCESS; Pages `33417043749` SUCCESS.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## Why v145 exists
User material homologation of v144 found a real Dashboard flicker: titles visibly alternated as if the page had a bad contact.

Root cause is proven, not inferred:
- `wip35-v142-dashboard-cockpit.js` runs its installer every 180 ms and repeatedly re-enters `loadCockpit`; after RPC completion it can call `render()` while Dashboard is active.
- inherited v143 Dashboard renderer produces an older H1/subtitle;
- `wip35-v143-feedback-polish.js` runs every 220 ms and rewrites those nodes to the approved final copy;
- those two cycles therefore alternate visible copy.

v145 is a stability correction only. It changes no financial rule, value, classification, backend writer or economic effect.

## v145 architecture
Branch: `v145-dashboard-stability`.
Green product head: `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`.

- Candidate `wip35-v145-candidate.html` inherits v142→v143/v144 composition without editing historical candidates.
- v144 lexical bridge and Atualizações layout remain hosted in the deepest inherited runtime.
- New marker: `single-refresh-title-stable-v1`.
- v145 wraps `__v143Dashboard` once so returned HTML already contains the approved H1/subtitle.
- After a valid cockpit exists, v145 locks the inherited v142 polling guard so the 180 ms loop cannot perform repeated Dashboard RPC/render work.
- Explicit `LTS_V145_REFRESH_DASHBOARD` remains available for a controlled one-shot read-only cockpit refresh.
- No permanent new v145 interval is added; install uses finite retry timeouts only.
- The outer candidate omits the inherited candidate badge to avoid another known cross-layer rewrite surface.

## Branch gate evidence
Workflow `33421305585`: SUCCESS. Artifact `9769043340`.

Desktop 1440×1000 and mobile 390×844 both prove:
- exact final title set = only `Sua vida financeira, em uma tela.`;
- exact final subtitle set = only `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- legacy poll guard locked;
- stable Dashboard renderer owns the active renderer;
- `renderDelta=0` during the temporal observation window;
- `rpcDelta=0` for `lts_browser_dashboard_cockpit_v1` during the same window;
- v144 Atualizações remains present with `classification-action-center-v2`, restaurant suggestion and confidence evidence;
- zero horizontal overflow and zero console/page errors.

The same workflow also reruns inherited parser/static v142, v142 browser smoke, v143 runtime/navigation smoke and button contract audit, all PASS.

This evidence is synthetic/unauthenticated browser evidence. It is **not authenticated visual E2E** and executes no backend financial write.

## Financial/backend invariants — unchanged
- Planning: management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; existing accrual R$3.700/mês; request-date projected FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027.
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle; R$578,68 historical sale difference remains unitemized.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031, no duplicate economic effect.
- Backend fingerprint remains `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS plus supplemental 16/16.

## Open blockers retained
- Human classification where evidence remains insufficient.
- Guided document association and PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics.
- Mastercard/Visa documentary gaps; never infer purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps; no fabricated post-2029 TR.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend without explicit decision.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.

## Gate from here to user re-test
1. Freeze v145 evidence/checkpoint and synchronize canonical backlog/gate/handoff.
2. Integrate v145 into `main` via normal fast-forward/PR path with `force=false`; no divergence overwrite.
3. On exact integrated main SHA require v145 stability workflow SUCCESS + Pages SUCCESS; reconfirm protected `index.html` blob and manifest still v144.
4. In a separate controlled exposure commit, switch `homologacao-current.json` to `wip35-v145-candidate.html` with `promotion_status: not_promoted`.
5. On exact exposure SHA require v145 stability workflow SUCCESS + Pages SUCCESS and reconfirm protected public index.
6. Only then tell the user to re-test the Dashboard at the fixed homologation URL.
7. Public `index.html` remains untouched until explicit user approval.
