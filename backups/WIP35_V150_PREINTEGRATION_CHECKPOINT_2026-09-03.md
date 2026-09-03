# WIP35 v150 expense/input/dashboard recomposition — pre-integration checkpoint — 03/09/2026

## Candidate
- Source branch: `v150-expenses-input-dashboard-recomposition`.
- Exact green product/gate SHA: `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- Candidate path: `wip35-v150-candidate.html`.
- Marker: `expense-input-dashboard-recomposition-v1`.
- Fixed homologation remains v148 at this checkpoint; v150 is not exposed yet.

## Exact branch gates
- v150 workflow run `33784295793`: SUCCESS.
- Job `100745221087`: SUCCESS.
- Artifact `9904891998`.
- Artifact digest `sha256:3a2550ddc480b17182cedfff16ef49d8756387195509816f163bc5d56145c8ea`.
- Architecture/static guardrails: SUCCESS.
- Inherited button contracts: SUCCESS.
- Inherited parser/static gate: SUCCESS.
- Inherited v146 repeated-navigation regression: SUCCESS, preserving 10 cycles × 7 destinations × desktop/mobile = 140 physical clicks.
- Inherited v147 guided document association: SUCCESS.
- Inherited v148 classification save→refresh lifecycle: SUCCESS.
- Inherited v149 document interpretation review: SUCCESS.
- v150 desktop/mobile recomposition smoke: SUCCESS.

## v150 product scope
- Dashboard is recomposed around `Disponível realizável até D+3`, with bank cash, D0 and vested D+3 resources separated.
- FGTS remains restricted/not immediate cash and is only shown as an additional D+30 contingency layer.
- Redundant top-level Planejamento navigation is hidden; detailed liquidity remains available inside Dashboard.
- Despesas separates nature from context/person and exposes documentary/system-review/classification-pending states without fabricating detail.
- Expense drilldown and Fluxo lookup use read RPCs only.
- Atualizações includes a reviewed-input shortcut that now routes to the existing `Entradas` preview UI, prefills `.phrase`, and adds no automatic writer.
- Existing explicit approval remains the only path that can later invoke the pre-existing reviewed-input writer.

## Guardrails
- `financial_writer_changed=false`.
- `classification_inference=false`.
- `permanent_polling=false`.
- Reviewed-input route status requires `target=Entradas`, `preview_only=true`, `writer_added=false`.
- The v150 smoke rejects writer-like RPC calls during the shortcut/read-only journey.
- No financial amount, classification, reconciliation rule, competence rule, valuation rule or economic effect was changed by this package.

## Release safety
- Public `index.html` remains outside the v150 package and must stay protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public root promotion remains unauthorized/not done.
- Authenticated visual E2E remains pending/not claimed.
- Real authenticated classification, natural-liquidity and PDF/image interpretation flows remain pending/unclaimed.
- Next step is a fresh no-divergence compare followed by normal `force=false` main integration, exact integrated-main gates, Pages verification, and only then controlled fixed-homologation exposure to v150.