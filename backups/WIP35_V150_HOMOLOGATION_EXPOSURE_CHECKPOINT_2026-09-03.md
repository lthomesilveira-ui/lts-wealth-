# WIP35 v150 fixed-homologation exposure checkpoint — 03/09/2026

## Candidate and integration
- Source branch: `v150-expenses-input-dashboard-recomposition`.
- Exact green product/gate SHA: `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- Candidate path: `wip35-v150-candidate.html`.
- Marker: `expense-input-dashboard-recomposition-v1`.
- Main integration/doc-alignment baseline immediately before exposure: `25e517a28f900e281966d00a44cba827e49efb85`.
- Exact integrated-main v150 workflow `33785378395`: SUCCESS.
- Exact integrated-main Pages `33785376825`: SUCCESS.

## Controlled fixed-homologation exposure
- Manifest exposure commit: `97fff4d35cc0c3edd24a11b458a1bed7d885ddcb`.
- `homologacao-current.json` now points to `v150` / `wip35-v150-candidate.html`.
- Manifest candidate/product SHA remains `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- `promotion_status` remains `not_promoted`.
- Public root `index.html` was not promoted or changed.

## Exact exposure-SHA gates
- v150 recomposition workflow `33796998363`: SUCCESS.
- v150 job `100786998249`: SUCCESS.
- v150 artifact `9909647698`.
- v150 artifact digest `sha256:735cc4082378302a8b04ad710898a485defe6cf7909f2f9af65e0e292e02d388`.
- Candidate smoke workflow `33796998174`: SUCCESS.
- v148 classification lifecycle workflow `33796998303`: SUCCESS.
- All 9 workflows triggered by the exposure commit reached a terminal conclusion; no `in_progress`, null conclusion, failure or cancellation remained in the exact-SHA run set at release closure.
- Pages workflow `33796996669`: SUCCESS.
- Inside the v150 exact exposure job, architecture/guardrails, inherited button contracts, inherited parser/static, v146 repeated navigation, v147 association, v148 lifecycle, v149 document interpretation and v150 desktop/mobile recomposition all completed SUCCESS.
- v146 regression remains 10 cycles × 7 destinations × desktop/mobile = 140 physical Playwright clicks.

## v150 product scope retained
- Dashboard centers `Disponível realizável até D+3`; bank cash, D0 and vested D+3 resources remain separated.
- FGTS stays restricted/not immediate cash; it is shown only as an additional D+30 contingency layer.
- Redundant top-level Planejamento navigation is hidden; detailed liquidity remains inside Dashboard.
- Despesas separates nature from context/person and keeps documentary/system-review/classification-pending states explicit without fabricated detail.
- Expense drilldown and Fluxo lookup remain read-only journeys.
- Atualizações reviewed-input shortcut routes to the existing `Entradas` preview UI, prefills `.phrase`, and adds no automatic writer.
- Existing explicit approval remains the only path that can later invoke the pre-existing reviewed-input writer.
- v149 read-only document interpretation review remains inherited/preserved.

## Financial/product guardrails
- `financial_writer_changed=false`.
- `classification_inference=false`.
- `permanent_polling=false`.
- Reviewed-input shortcut remains `target=Entradas`, `preview_only=true`, `writer_added=false`.
- No financial amount, classification, reconciliation, competence, valuation or economic-effect rule changed in v150.
- Public `index.html` remains protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` after exposure.
- Public root promotion remains unauthorized/not done.
- Authenticated visual E2E remains pending/not claimed.
- Real authenticated classification save→refresh, natural-liquidity save→refresh and PDF/image interpret→review remain pending/unclaimed.

## Release state
- Fixed homologation release: **v150**.
- Material user homologation is now the next release gate.
- Public promotion remains a separate explicit user authorization.
