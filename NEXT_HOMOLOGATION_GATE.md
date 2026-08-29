# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a new public candidate. This file is operational and must stay aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current public baseline
- WIP35-v136 remains the canonical public fallback at `index.html`.
- WIP35-v137 exists only as isolated candidate `wip35-v137-candidate.html`; it does not replace `index.html`.
- Real authenticated visual E2E remains pending/unclaimed.

## Current data-recovery position — 2026-08-29
- Historical expense total: R$ 8,623,752.53 invariant.
- Certified historical category-allocation cycles: 34.
- Historical effective rows through 2026-08-29: 3,767.
- Rows with recovered category detail: 3,449.
- Remaining card aggregate fallback rows: 318, totaling R$ 2,714,803.16.
- Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- Mastercard Itaú 2025 candidate only: Jan, Feb, Jul, Oct.
- Mastercard Itaú 2025 blocked: Sep, Dec.
- Mastercard Itaú 2024 pending ledger identities: Jan/1829/R$53,652.87; Feb/1871/R$58,667.61; Apr/1966/R$47,802.70; Jun/2061/R$48,393.80; Jul/2104/R$51,947.18; Nov/2281/R$45,259.24.

## WIP35-v137 candidate package
### Despesas
- Implemented click interaction on executive category ranking and 12-month category trends.
- A clicked category opens a category-focus lens based only on existing `category_trends_12m` evidence.
- Month buttons delegate to the existing certified `ex135OpenMonth` / `lts_browser_expense_month_detail_v2` path.
- When no monthly documentary series exists, the candidate explicitly says detail is unavailable and does not fabricate merchant/purchase information.

### Atualizações
- Added explicit workflow vocabulary: Recebido → Interpretado → Reconciliado → Decisão necessária → Resolvido.
- The UI states that these are possible stages and does not infer a completed stage merely because an item is absent from the active queue.
- Active queue counts continue to come from existing `updates.items` / `updateIsAction` semantics.
- Existing confirmation/evidence/classification write paths are untouched.

### Candidate safety / QA
- Candidate is a same-origin wrapper over WIP35-v136, so fallback remains literally unchanged.
- Candidate contains no direct Supabase RPC, `fetch`, insert/update/delete/upsert or new financial write path.
- Static candidate smoke: 12/12 PASS.
- Node parser: PASS.
- Expense v9: 19/19 PASS; 34/34 certified cycles close.
- Expense v10: 18/18 PASS.
- Core financial regression: 15/15 PASS.
- Projection bridge: PASS via core suite; max absolute residue ~R$0.0193 < R$0.03 tolerance.
- Operational cache health: PASS via core suite.
- GitHub Pages build for candidate commit `31d604e8...`: SUCCESS (run 33265232777).
- Candidate QA evidence persisted in `backups/wip35-v137-candidate-smoke-2026-08-29.txt`.
- Real authenticated visual E2E remains pending/unclaimed.

## Minimum package before next user look
1. Data/history: materially reduce historical card aggregate fallback using only documentary exact closures. Do not require all 318 rows to be eliminated; blocked evidence gaps remain explicit. **Status: partially achieved; 34 exact cycles and recovery continues in parallel.**
2. Despesas UX: visible navigation/drilldown improvement from category/rank/trend into evidence-backed detail. **Status: implemented in v137 candidate.**
3. Atualizações UX: make lifecycle/checklist materially clearer without inventing status. **Status: implemented in v137 candidate; backend still does not expose a complete persisted lifecycle ledger for every document.**
4. Actionability: touched modules must tell the user what can be done next. **Status: implemented for category focus and active updates queue.**
5. Regression: expense v9/v10, core financial regression, projection bridge and operational health green. **Status: green.**
6. Candidate QA: parser and smoke green; prior public v136 stays fallback. **Status: green and fallback preserved.**
7. Visual QA: do not claim authenticated visual E2E unless actually performed. **Status: pending/unclaimed.**

## Current readiness assessment
- Backend/history: advanced; 34 exact certified cycles; further recovery remains open but is not a blocker for a useful visual candidate.
- Despesas visible package: material improvement implemented in v137 candidate.
- Atualizações visible package: lifecycle vocabulary and active-work framing implemented in v137 candidate.
- Regression safety: green.
- Candidate static/parser safety: green.
- Pages deployment: successful for candidate commit.
- Publish readiness for replacing public `index.html`: NOT AUTHORIZED/NOT DONE. Keep v136 fallback until user homologation.
- User-look readiness: READY for next user inspection of the isolated candidate, with authenticated visual E2E explicitly still pending.

## Trigger to ask user to look again
The trigger is now satisfied for the isolated candidate:
- visible Despesas interaction implemented and checked;
- Atualizações lifecycle materially clearer;
- latest financial gates green;
- candidate parser/static smoke green;
- GitHub Pages candidate deployment successful;
- public v136 fallback preserved.

Historical recovery continues in parallel. Blocked documentary gaps remain explicit and are never solved by inference.
