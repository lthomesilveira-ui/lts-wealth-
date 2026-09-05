# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline — v158 — 05/09/2026
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation manifest points to **v158** through `wip35-v158-candidate.html`.
- Source branch: `v158-native-core-auth-mobile-recovery`.
- Branch staged head: `ecc7feb534921a93ac54064cd7e743d841a2486c`.
- Controlled exposure head: `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated visual/data E2E: PENDING / NOT CLAIMED.
- Immutable evidence: `backups/WIP35_V158_NATIVE_CORE_AUTH_MOBILE_RECOVERY_CHECKPOINT_2026-09-05.md`.

## Why v157 was rejected
- Material real-iPhone evidence superseded the deterministic WebKit gate.
- On the user's screenshot, all top financial KPIs were unavailable (`—`), the `Despesas (mês)` status text overlapped, and the bottom navigation was horizontally clipped with `Atualizações` not fully accessible.
- The screenshot was captured inside an Instagram in-app browser context. It does not prove whether that context shared the user's authenticated session, so do not over-attribute the failure to authentication.
- The definite product problem was architectural at the presentation boundary: v157 could display its own shadow Dashboard while the native core authentication/data state behind it was unavailable, producing an empty-looking financial product instead of a truthful native login/app state.

## v158 correction contract
- No shadow/synthetic financial Dashboard at the candidate layer.
- `wip35-v158-candidate.html` loads exactly one full-screen same-origin native/proven core through `index.html?v158-native-core`.
- The native core owns authentication, financial data, state and route behavior.
- If the current browser context is not authenticated, show the native login rather than fake financial KPI dashes.
- If authenticated, show the native product/data; the candidate must not synthesize financial values.
- Mobile adaptation is restricted to the established six-route row: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- No `document.write`, permanent `setInterval` or `MutationObserver`; bounded retry burst only.
- Public `index.html` is not modified by this candidate.

## Exact release evidence
- Branch v158 native-core/WebKit run `33973465268`: SUCCESS.
- Exact-main/exposure v158 run `33973672077`: SUCCESS on head `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- WebKit iPhone-equivalent gate validates exactly one native core frame, zero top-level synthetic KPI cards, truthful native authentication state, no top-level horizontal overflow and the single-row mobile navigation policy.
- Chromium desktop native-core smoke passes.
- Exact exposure GitHub Pages run `33973671958`: SUCCESS on the same exposure head.
- CI is unauthenticated. These gates do not prove the user's authenticated financial session and must not be represented as authenticated E2E.

## Current material user gate — v158
1. Open the fixed homologation URL on the real iPhone.
2. The page must no longer present an artificial Dashboard full of `—` values while hiding the native app state.
3. If that browser context has no active LTS session, the native login should be visible. Authenticate normally in that context; this is not a financial write.
4. After authentication, real product data must load through the native app.
5. Physically navigate Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard; no clipped route, dead control or route trap.
6. Confirm there is no overlapping text regression like the v157 `Despesas (mês)` card.
7. Do not perform a financial write merely for QA.
8. Public promotion remains a separate explicit authorization and cannot be inferred from homologation approval.

## Current FGTS / planning invariant
- Latest documentary FGTS balance: R$22.432,31 at 21/08/2026.
- Restricted / approximately D+30 contingency; excluded from D+3.
- No future FGTS contributions projected.
- Historical R$3.700/month accrual and dependent R$32.309,05 request-date / worst-case outputs are historical evidence only, not current validated forecast.
- First-negative date and management/action date must be revalidated under the conservative FGTS rule and shown separately if different.

## Open blockers retained
- Material authenticated physical-iPhone homologation of v158.
- Real authenticated visual/data E2E.
- Real authenticated classification save→refresh/resolved disappearance/self-heal/`O que mudou`.
- Real authenticated PDF/image interpretation→review.
- Authenticated natural-liquidity save→refresh→visible result.
- Append-only auditable cancellation/reversal semantics.
- Server-side transaction search completion, total and Excel-compatible CSV export.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary gaps; never pattern-fill.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps and duplicate excess; no fabricated post-2029 TR or automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential/provider commitment without explicit user decision.
- Continue historical pending-item audit back to 07/07/2026.
- Public promotion only after explicit user approval.