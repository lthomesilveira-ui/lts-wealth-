# WIP35 v160 real-data bridge homologation checkpoint — 05/09/2026

## Trigger / real-device evidence
- v159 is rejected as product-ready by material real-iPhone evidence supplied by the user.
- The v159 screenshot showed that the official-reference/mobile presentation and six-route row had improved, but all five liquidity-first financial KPIs remained unavailable (`—`).
- The failure was therefore not accepted as a visual-only issue. A Dashboard that renders successfully without material financial data is not considered a successful boot.
- Root cause isolated in the release layer: Dashboard readiness could be reached after patch/boot activity even when no material financial cockpit data had actually been received.

## v160 correction
- Source branch: `v160-real-data-bridge`.
- Candidate: `wip35-v160-candidate.html`.
- Final staged candidate head: `9f49c8637796d0e56b012896bedb55f5e29259c1`.
- Controlled homologation exposure commit on `main`: `cbc4bc9d7e4798a9e97b80feb7510af535ac6d43`.
- v160 keeps the v156 liquidity-first/offical-reference Dashboard baseline but changes data readiness from presentation-driven to evidence-driven.
- It recursively traverses the bounded same-origin frame chain looking for the existing application state and Supabase/RPC bridge.
- Read-only financial cockpit recovery uses existing RPC `lts_browser_dashboard_cockpit_v1` when material cockpit state is not already present.
- The prototype Dashboard is shown only after at least one material financial field is available. If material data is unavailable, v160 exposes the native/login/core state rather than masking the failure behind a Dashboard full of dashes.
- v160 has exclusive ownership of the six candidate navigation controls, avoiding the previous race with nested release navigation handlers.
- Six established routes remain: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- `synthetic_financial_values_added:false`; no user-facing financial values are fabricated by v160.
- No `document.write`, permanent `setInterval` or `MutationObserver` is introduced.
- No financial/backend writer is introduced by the v160 bridge.

## Deterministic evidence
- Final branch v160 real-data bridge run `33991299085`: **SUCCESS** on candidate head `9f49c8637796d0e56b012896bedb55f5e29259c1`.
- Controlled bridge fixture validated all five liquidity-first KPI slots with non-empty values in Chromium desktop and WebKit iPhone-equivalent contexts.
- Physical navigation validated the six candidate routes and return to Dashboard, with candidate route ownership, no horizontal clipping and no top-level overflow.
- No-fixture gate validated truthful fallback: when material cockpit data is unavailable, the empty prototype Dashboard cannot remain exposed and the native/core frame must remain visible.
- Exact-main v160 gate `33992238668`: **SUCCESS** on exposure head `cbc4bc9d7e4798a9e97b80feb7510af535ac6d43`.
- Exact GitHub Pages deployment `33992238643`: **SUCCESS** on the same exposure head.
- Other exact-main stability checks on the exposure head also completed successfully.
- CI remains unauthenticated. None of these gates is represented as authenticated user financial/data E2E on the user's physical iPhone.

## Homologation exposure
- `homologacao-current.json` points to `v160` / `wip35-v160-candidate.html`.
- `promotion_status:not_promoted` remains in force.
- Fixed homologation remains `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` was not modified; public-root promotion remains unauthorized/not done.

## Product / financial invariants preserved
- Liquidity-first hierarchy: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês); pending actions secondary.
- Missing evidence remains unavailable rather than being converted to R$0,00.
- `Contas + curto prazo` is evidence-only: `bank_cash + d0` when both exist; otherwise `through_d3 - vested` only when both exist.
- Latest documentary FGTS remains R$22.432,31 as of 21/08/2026; restricted approximately D+30, never D+3; no future FGTS accrual projection.
- Facts remain above projections; scenarios are never facts.
- No new money-changing, classification, merchant, competence, valuation or reconciliation assumptions were introduced.

## Delivery boundary / authenticated evidence
- v160 is technically delivered to fixed homologation with exact-main and exact-Pages deterministic gates green.
- Authenticated physical-iPhone financial/data E2E remains pending and explicitly unclaimed because CI does not possess the user's authenticated browser session.
- The release acceptance criterion is now truthful: the user must never be shown a financially empty prototype Dashboard as a successful state. Material data must populate it, otherwise the actual native/login/core state must surface.
- Public production promotion remains a separate explicit user authorization.

## Open dependencies preserved
- Server-side transaction search through `lts_browser_transactions_v1`, including total and Excel-compatible CSV export.
- Planning/FGTS recalculation under no-future-accrual, separating first-negative and management/action dates when different.
- Expense density/ranking/decision-useful insights and evidence-only reduction of `A classificar`.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation → review.
- Natural-liquidity authenticated save → refresh → visible.
- Append-only auditable cancellation/reversal semantics.
- Mastercard/Visa documentary recovery; never pattern-fill purchases.
- CIPÓ: consortium R$303,60 delta; R$6.654,50 arithmetic only from R$6.502,70 + R$151,80 on different dates; condominium source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70; no fabricated post-2029 TR; no automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/support/SLA/product×bank; no provider consent/spend/credential/commercial decision without explicit user authorization.
- Historical pending-item audit back to 07/07/2026.
- Preserve Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Preserve search evidence Mastercard 239 rows from 01/11/2013 to 12/04/2028.
- Preserve card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36; C6 Aug/2024 R$66,70 gap.
- Preserve RSU vested 459.483 units / R$32.772,30 / D+3; 283-unit sale net R$19.095,04; R$578,68 unexplained.
- Preserve Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031 exactly once economically.
- Preserve Open Finance provider-neutral QA 14/14; backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites + supplemental v143 16/16; v146 140 physical navigation clicks.
- Public promotion only after explicit user authorization.
