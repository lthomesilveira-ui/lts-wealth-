# WIP35 v157 iOS/WebKit homologation checkpoint — 05/09/2026

## Trigger / real-device evidence
- v156 is rejected as product-ready after real iPhone homologation because financial data did not load and route navigation remained inoperable for the user.
- This real-device failure supersedes the prior Chromium-only confidence. v157 is specifically a WebKit/iPhone recovery package, not an architecture restart.

## Root correction
- Candidate: `wip35-v157-candidate.html`.
- Product candidate commit: `c88955095a9e07de72b11921cdc45a7edce7f6a0`.
- WebKit gate workflow commit: `89c5be2915936e8838c7322a045a0636c46012dd`.
- v157 removes the fragile dynamic reconstruction of the visual shell used by v156: no fetch/string injection of `wip35-v154-candidate.html`, no `document.write`, no `setInterval`, no `MutationObserver`.
- v157 uses a static official-reference shell and the existing same-origin core through `wip35-v151-candidate.html?v157-parent`.
- Boot, financial-model read and route retries are bounded; steady state has no permanent polling loop.
- Mobile navigation remains persistent for Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações.

## Dashboard / financial contract preserved
- Liquidity-first KPIs remain `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
- Missing numeric evidence remains unavailable/`—`; it is never fabricated as R$0,00.
- `Contas + curto prazo` uses only evidenced arithmetic: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist.
- FGTS latest documentary balance remains R$22.432,31 as of 21/08/2026, restricted / approximately D+30 and never D+3.
- No future FGTS deposits/accrual are projected.
- Facts remain above projections and scenarios are never facts.
- No financial/backend writer was added by v157.

## Deterministic WebKit / browser evidence
- Source branch: `v157-ios-webkit-nav-recovery`.
- Branch exact staged head: `cb0b4420c030c6336db59249e11bf1307e9ce500`.
- Branch WebKit run `33970332769`: SUCCESS.
- Exact branch-head WebKit run `33970468539`: SUCCESS.
- WebKit iPhone-equivalent viewport 390×844, touch enabled: physical route sequence Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard passed.
- WebKit fixture-backed Dashboard loaded all five liquidity-first KPIs.
- WebKit steady state remained responsive for 20 seconds with no repeated Dashboard patching, no material DOM churn and no page-level horizontal overflow.
- WebKit no-fixture smoke booted the existing core, remained responsive for 12 seconds and physically opened Fluxo Diário.
- Chromium desktop 1312×1199 parity smoke passed.
- CI is unauthenticated; none of this is claimed as authenticated user financial/data E2E.

## Integration / homologation exposure
- v157 was integrated to `main` by normal fast-forward, force=false.
- Integrated/exposed main SHA: `cb0b4420c030c6336db59249e11bf1307e9ce500`.
- Exact-main v157 WebKit gate run `33970591125`: SUCCESS.
- Exact-main GitHub Pages run `33970589882`: SUCCESS.
- `homologacao-current.json` points to `v157` / `wip35-v157-candidate.html` with `promotion_status:not_promoted`.
- Fixed homologation remains `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Protected public `index.html` remains unchanged; public promotion is not authorized and was not performed.

## Current material gate
- The remaining release gate is real authenticated iPhone verification because the CI environment cannot reproduce the user's authenticated session and exact physical device runtime.
- User verification must confirm that real financial data loads and that Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard works without dead controls or route trap.
- Real authenticated visual/data E2E remains pending and explicitly unclaimed until that evidence exists.

## Open dependencies preserved
- Server-side incremental transaction search through `lts_browser_transactions_v1`, including total and Excel-compatible CSV export.
- Planning/FGTS recalculation under the no-future-accrual rule, with first-negative date and management/action date separated when different.
- Expense density/ranking/decision-useful insights and evidence-only reduction of `A classificar`.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation → review.
- Natural-liquidity authenticated save → refresh → visible.
- Append-only auditable cancellation/reversal semantics.
- Mastercard/Visa documentary recovery; never pattern-fill purchases.
- CIPÓ documentary/reconciliation blockers remain unchanged: consortium R$303,60 delta; different-date R$6.654,50 arithmetic; condominium source absent; raw/dedup gaps; duplicate excess; no fabricated post-2029 TR or automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/support/SLA/product×bank coverage and any consent/spend/provider decision.
- Historical pending-item audit back to 07/07/2026.
- Preserve official-reference visual language, compact Atualizações, mobile/desktop usability, fixed links, backup and traceability.
- Public promotion only after explicit user authorization.
