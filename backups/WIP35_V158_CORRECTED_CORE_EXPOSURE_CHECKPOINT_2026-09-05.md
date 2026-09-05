# WIP35 v158 corrected-core exposure checkpoint — 05/09/2026

## Trigger
- User correctly reported that the fixed homologation URL was opening v136 even though the manifest said v158.
- Root cause: the first v158 candidate embedded public `index.html`, whose protected content intentionally remains WIP35-v136.
- This was a release-wiring defect, not a cache assumption.

## Corrected candidate
- Candidate path remains `wip35-v158-candidate.html`.
- Corrected product head: `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- The candidate no longer references `index.html?v158-native-core`.
- It loads the existing evidence-bearing product core chain through `wip35-v151-candidate.html?v158-native-core`.
- Because that historical core is a same-origin wrapper chain, v158 now recursively descends the bounded iframe chain to locate the actual login/app document before determining readiness or applying the mobile navigation constraint.
- The v158 top layer owns no financial KPI values and does not fabricate data.
- No `document.write`, permanent `setInterval` or `MutationObserver`; retry assistance is bounded.
- Public `index.html` remains unchanged and promotion remains unauthorized.

## Deterministic evidence
- The first shallow nested-core attempt run `33974643243` failed because readiness was checked only in the first wrapper document. This failed run is superseded, not erased.
- Corrected WebKit/Chromium run `33974901298`: SUCCESS on exact candidate head `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- WebKit iPhone-equivalent authentication-truthfulness gate: SUCCESS.
- Chromium desktop core smoke: SUCCESS.
- Exact GitHub Pages deployment `33974901021`: SUCCESS on the same candidate head.
- CI remains unauthenticated; authenticated user financial/data E2E is not claimed.

## Homologation manifest
- Manifest refresh commit: `05ea21cabcf6078e050e3e532877204450476a6c`.
- `homologacao-current.json` points to `v158` / `wip35-v158-candidate.html` and now stamps candidate head `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- `promotion_status:not_promoted` remains unchanged.
- Fixed homologation URL remains `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.

## Material gate remaining
- Real physical-iPhone/session validation remains required because deterministic CI cannot reproduce the user's authenticated browser context.
- The corrected homologation must no longer present v136 as v158.
- If browser context is unauthenticated, the real/core login state must surface; once authenticated, real product data must load.
- Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard must be physically usable without clipping, dead controls or route traps.

## Financial/product invariants preserved
- Liquidity-first product hierarchy remains the target: bank cash, short-term resources, vested RSUs D+3, FGTS separate/restricted approximately D+30, monthly expenses; pending actions secondary.
- Latest documentary FGTS remains R$22.432,31 as of 21/08/2026; no future FGTS accrual; never D+3.
- Missing evidence remains unavailable rather than fabricated R$0,00.
- Facts remain above projections; scenarios never become facts.
- No new financial writer was introduced.

## Open dependencies preserved
- Real authenticated visual/data E2E.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation → review.
- Natural-liquidity authenticated save → refresh → visible.
- Append-only auditable cancellation/reversal semantics.
- Server-side incremental transaction search + total + Excel-compatible CSV export.
- Expense density/ranking/decision-useful insights and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery; never pattern-fill.
- Planning/FGTS recalculation under no-future-accrual, separating first-negative and management/action dates when different.
- CIPÓ documentary/reconciliation blockers remain unresolved as previously recorded.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/support/SLA/product×bank coverage and any consent/spend/provider decision.
- Historical pending-item audit back to 07/07/2026.
- Preserve official-reference visual language, compact Atualizações, mobile/desktop usability, fixed links, backup and traceability.
- Public promotion only after explicit user authorization.
