# LTS Wealth — WIP35 v145 Pre-Integration Checkpoint

Checkpoint date: 2026-08-31

## Purpose
Freeze the evidence-backed Dashboard stability correction before integration. This checkpoint does not authorize public promotion, does not change any financial rule, and does not claim authenticated visual E2E.

## User-reported regression
During material homologation of v144, the Dashboard headings visibly alternated as if the screen had a bad contact.

## Proven root cause
- `wip35-v142-dashboard-cockpit.js` runs `install` every 180 ms.
- Its `loadCockpit` can repeatedly call `lts_browser_dashboard_cockpit_v1` and `render()` while Dashboard is active.
- `wip35-v143-life-real.js` Dashboard renderer returns older H1/subtitle copy.
- `wip35-v143-feedback-polish.js` runs every 220 ms and rewrites the head to the final approved copy.
- Those competing cycles create the visible flicker.

## Frozen branch evidence
- Branch: `v145-dashboard-stability`.
- Product head: `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`.
- Tree: `c782d866f13fbd7091bbd7ff6131effb9a5dd79a`.
- Workflow run: `33421305585` SUCCESS.
- Artifact: `9769043340`.

## v145 architecture
- Candidate `wip35-v145-candidate.html` preserves the inherited v142→v143/v144 product composition; no historical candidate is edited.
- v144 lexical bridge and Atualizações layer remain hosted in the deepest inherited runtime.
- Marker `single-refresh-title-stable-v1`.
- `__v143Dashboard` is wrapped once so generated HTML already contains the final H1/subtitle.
- After valid cockpit data exists, v145 locks `__LTS_V142_DASHBOARD_LOADING` to prevent the inherited 180 ms loop from performing repeated Dashboard RPC/render work.
- A controlled read-only `LTS_V145_REFRESH_DASHBOARD` remains for explicit one-shot cockpit refresh.
- v145 adds no permanent interval; boot uses finite retries only.
- No direct SQL/backend financial writer is introduced.
- Technical `_tmp` created during branch preparation is deleted from the v145 tree; it never affected financial data or product behavior.

## Temporal browser evidence
Desktop 1440×1000 PASS:
- title set: only `Sua vida financeira, em uma tela.`;
- subtitle set: only `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- legacy poll locked: true;
- stable renderer owner: true;
- `renderDelta=0`;
- `rpcDelta=0` for `lts_browser_dashboard_cockpit_v1`;
- v144 Atualizações root/suggestion/confidence preserved;
- zero overflow; zero errors.

Mobile 390×844 PASS with the same title/subtitle, ownership, zero-render, zero-RPC and zero-overflow/error results.

The workflow also reran inherited parser/static v142, v142 browser smoke, v143 runtime/navigation smoke and button contract audit — all PASS.

This is synthetic/unauthenticated browser evidence. No backend financial write is executed. It is not authenticated visual E2E.

## Release guardrails
- Fixed homologation remains v144 at this stage.
- v144 exposure SHA `e8c522728a9c5740be89f1bcf08c8301ceecee78` had post-switch runs `33417045276`, `33417045163`, `33417043749` all SUCCESS.
- Public `index.html` remains protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized.

## Financial/backend parity
No financial rule/value/classification/backend writer changed. Backend fingerprint remains `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS and supplemental 16/16 PASS remain inherited.

## Open blockers carried forward
- authenticated visual E2E;
- guided document association / improved PDF-image interpretation;
- authenticated classification save/refresh/self-heal path;
- authenticated natural-liquidity save→refresh→visible result and append-only reversal semantics;
- Mastercard/Visa historical documentary gaps;
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps, no fabricated post-2029 TR;
- Volvo exact trim/km;
- Open Finance pricing/SLA/product×bank coverage;
- human classification when evidence remains ambiguous;
- public promotion only after explicit user approval.

## Authorized next sequence
1. Commit this checkpoint + canonical docs on the green branch.
2. Integrate v145 into `main` without force/divergence overwrite; keep fixed homologation on v144.
3. Require v145 stability workflow + Pages on exact integrated SHA and reconfirm protected public index.
4. In a separate exposure commit switch manifest to v145 with `promotion_status: not_promoted`.
5. Require same-SHA post-switch v145 stability workflow + Pages and public index unchanged.
6. Only then ask the user to re-test Dashboard stability.
