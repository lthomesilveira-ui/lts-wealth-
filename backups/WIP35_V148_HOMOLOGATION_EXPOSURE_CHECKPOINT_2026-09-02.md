# WIP35 v148 fixed-homologation exposure checkpoint — 02/09/2026

## Exposure
- Exact exposure SHA: `c6ff4ec0282fbdfaacdeb1ef60c5edd92fe6dc24`
- Manifest: v148 / `wip35-v148-candidate.html`
- Candidate head/SHA: `b902f84a71a4dc1aa35d955e07b5280775cb9ca5`
- Integrated pre-exposure SHA: `0da167c66ec59f424e143d74ecd12ea6f4207364`
- Promotion status: `not_promoted`
- Public fallback: `index.html`
- Protected public blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`

## Exact exposure-SHA gates
- Pages: `33661134816` SUCCESS
- Candidate-smoke legacy: `33661135368` SUCCESS
- v144 Atualizações: `33661135475` SUCCESS
- v145 Dashboard: `33661135553` SUCCESS
- v146 navigation/classification: `33661135606` SUCCESS
- v147 guided document association: `33661135763` SUCCESS
- v148 classification lifecycle: `33661135583` SUCCESS

The v148 workflow includes architecture/guardrails, button census, inherited parser/static, v146 repeated navigation, v147 desktop/mobile document association and v148 desktop/mobile classification lifecycle.

## v148 product evidence
- Existing writer `lts_browser_semantic_feedback_v1` is called once per explicit classification save.
- Existing reader `lts_browser_product_v1` reloads the product; a missing key confirms resolved disappearance.
- A writer success followed by read failure shows `Decisão salva · verificação pendente`; manual retry performs only the reader call.
- Session-scoped `O que mudou` records the resolved item and before→after pending count.
- Mutation injection is state-idempotent and does not use permanent polling.
- No amount, category inference, financial rule, backend schema, reconciliation or public fallback changed.

## Live verification truth
- The fixed homologation page loaded publicly with title `LTS Wealth · Homologação`.
- The served redirect resolved to `wip35-v148-candidate.html` with candidate SHA `b902f84a…` in the query, and the nested candidate/login surface loaded.
- A direct JSON-tab request was blocked by the cloud browser client; repository manifest, exact Pages success and the served redirect independently agree on v148.
- No credentials were entered and no authenticated visual E2E was performed; do not claim it.

## Remaining gates and backlog
- Material user homologation is now permitted for v148.
- Real authenticated classification save→refresh/visual E2E remains pending.
- Public root promotion remains blocked until explicit user authorization.
- PDF/image interpretation, natural-liquidity authenticated lifecycle and append-only reversal, Despesas refinement, evidence-only classification reduction, Mastercard/Visa recovery, CIPÓ blockers, Volvo trim/km, Open Finance pricing/SLA/product×bank and performance after correctness remain open.
