# WIP35 v158 native-core/auth/mobile recovery checkpoint — 05/09/2026

## Trigger / real-device evidence
- v157 is rejected as product-ready by material real-iPhone evidence supplied by the user.
- The screenshot from the user's iPhone shows the fixed homologation opened inside an Instagram in-app browser context. All top financial KPIs are unavailable (`—`), the `Despesas (mês)` card has overlapping status text, and the fixed bottom navigation is clipped horizontally with `Atualizações` not fully accessible.
- The screenshot proves that v157 did not deliver a usable real-device product experience. It does not, by itself, prove whether the in-app browser has the same authenticated session as Safari/other contexts.
- The definite v157 product defect is that its shadow/synthetic Dashboard could mask the native core authentication/data state behind an empty financial presentation.

## v158 correction
- Source branch: `v158-native-core-auth-mobile-recovery`.
- Candidate: `wip35-v158-candidate.html`.
- Branch staged head: `ecc7feb534921a93ac54064cd7e743d841a2486c`.
- Controlled homologation exposure commit on main: `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- v158 removes the shadow financial Dashboard completely. The top-level candidate does not own or fabricate financial KPI values.
- v158 loads exactly one full-screen same-origin native/proven core through `index.html?v158-native-core`; the native core owns authentication, financial data and route behavior.
- If the browser context is not authenticated, v158 exposes the native login instead of displaying a fake empty financial Dashboard.
- If the native core is ready, the mobile layer only constrains the established six-route navigation to a single fixed row: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- No `document.write`, permanent `setInterval` or `MutationObserver` is used; boot assistance is a bounded retry burst only.
- Public `index.html` itself is not changed by v158 and remains the protected fallback.

## Deterministic evidence
- Branch v158 native-core/WebKit run `33973465268`: SUCCESS.
- Exact-main/exposure v158 run `33973672077`: SUCCESS on head `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- WebKit iPhone-equivalent gate verifies one native core frame, zero top-level synthetic KPI cards, truthful native authentication state, no top-level horizontal overflow and mobile single-row navigation policy.
- Chromium desktop native-core smoke also passes.
- GitHub Pages deployment run `33973671958`: SUCCESS for the exact exposure head `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- CI remains unauthenticated. None of these gates is represented as authenticated user financial/data E2E.

## Homologation exposure
- `homologacao-current.json` points to `v158` / `wip35-v158-candidate.html` with `promotion_status:not_promoted`.
- Fixed homologation remains `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public root promotion remains unauthorized/not done.

## Product/financial invariants preserved
- Liquidity-first product hierarchy remains the target for the native product: bank cash, short-term resources, vested RSUs D+3, FGTS separate/restricted approximately D+30, monthly expenses; pending actions secondary.
- Missing financial evidence must remain unavailable rather than fabricated as R$0,00.
- Latest documentary FGTS remains R$22.432,31 as of 21/08/2026; no future FGTS accrual projection; FGTS never belongs to D+3.
- Facts remain above projections; scenarios are never facts; no new financial writer was introduced.

## Current material gate
- Real authenticated physical-iPhone verification remains required. The expected behavior is now binary and truthful: an unauthenticated browser context must show the native login; an authenticated context must show the native app/data rather than a shadow Dashboard full of dashes.
- Once authenticated in that browser context, Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard must be physically operable without clipped navigation or route traps.
- Real authenticated visual/data E2E remains pending and explicitly unclaimed until this evidence exists.

## Open dependencies preserved
- Server-side incremental transaction search through `lts_browser_transactions_v1`, including total and Excel-compatible CSV export.
- Planning/FGTS recalculation under no-future-accrual, separating first-negative and management/action dates when different.
- Expense density/ranking/decision-useful insights and evidence-only reduction of `A classificar`.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation → review.
- Natural-liquidity authenticated save → refresh → visible.
- Append-only auditable cancellation/reversal semantics.
- Mastercard/Visa documentary recovery; never pattern-fill purchases.
- CIPÓ documentary/reconciliation blockers remain unchanged.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/support/SLA/product×bank coverage and any consent/spend/provider decision.
- Historical pending-item audit back to 07/07/2026.
- Preserve official-reference visual language in the product itself, compact Atualizações, mobile/desktop usability, fixed links, backup and traceability.
- Public promotion only after explicit user authorization.
