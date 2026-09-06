# LTS Wealth — Canonical App v1 functional homologation checkpoint — 06/09/2026

## Purpose
Immutable checkpoint for the first materially functional single-frontend canonical LTS Wealth candidate. This checkpoint supersedes the planning-only canonical checkpoint as the current operational handoff while preserving every unresolved financial/documentary dependency.

## Canonical product state
- Canonical frontend: `canonical-app.html`.
- No iframe/release-wrapper chain is part of the canonical product.
- Direct authenticated Supabase/RPC integration is used by the same frontend.
- Canonical app owns the six routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Explicit loading, unauthenticated, error and data-ready states are preserved.
- `index.html` public fallback remains protected and unchanged; public promotion remains unauthorized.

## Exact source / integrity evidence
- Functional app content commit: `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`.
- Functional app size: 79,339 bytes.
- Functional app SHA-256: `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`.
- Fixed homologation exposure commit: `e6f3ab7421d5b7cb1986df768835f9d826536d9d`.
- Manifest traceability refresh commit on active branch: `afdfc070528f17e2e906a53e54de74ff298d90aa` records the exact exposure SHA rather than `pending-fast-forward`.
- Public `index.html` protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Deterministic functional gate
Workflow run `34003647351`: **SUCCESS**.

Validated in Chromium desktop 1312×1199 and WebKit mobile 390×844:
- five liquidity-first KPI cards populated under controlled fixture;
- all six physical route controls and return to Dashboard;
- Fluxo Diário account switch between Consolidado and Itaú;
- Despesas nature × context lens;
- Despesas drilldown interaction and historical period selector;
- Patrimônio executive summary / FGTS presence;
- Cartões open-invoice and next-due surfaces;
- Atualizações classification queue;
- fixture classification writer intentionally disabled;
- incremental transaction search for `Mastercard` returning controlled result;
- CSV export enabled after a result exists;
- Documents lifecycle area present;
- no iframe;
- no horizontal overflow;
- mobile six-item navigation not clipped;
- no browser page errors;
- no-fixture unauthenticated state exposes the login form rather than a fake financial Dashboard.

Gate artifact:
- artifact id `9980249754`;
- artifact digest `sha256:10aaad7ea9b27920562d32ce69462249fdd3d03818caffe2fe3d985527b6b5e0`;
- visual evidence includes `canonical-desktop.png`, `canonical-mobile.png` and `canonical-updates.png`.

This is deterministic unauthenticated/fixture evidence. It is **not** an authenticated physical-iPhone financial/data E2E and must never be represented as one.

## Fixed homologation / Pages
- Fixed homologation remains `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- `homologacao.html` now accepts the exact canonical target `canonical-app.html` in addition to the guarded legacy candidate naming pattern.
- `homologacao-current.json` now selects `canonical-v1` / `canonical-app.html` / `promotion_status:not_promoted`.
- Exact Pages build/deployment for exposure commit `e6f3ab7421d5b7cb1986df768835f9d826536d9d`: run `34003976631` — **SUCCESS**.
- Public root was not promoted or changed.

## Canonical functional coverage now implemented
### Dashboard
- Official-reference executive visual language and liquidity-first hierarchy.
- KPIs: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês).
- Dashboard action/deep-link surfaces retained.

### Fluxo Diário
- Same canonical route supports Consolidado, Itaú, Bradesco and C6.
- Existing financial rules remain authoritative: facts > projections, own bank↔liquidity transfers economic effect zero, no card-invoice expense duplication.

### Despesas
- Direct read path `lts_browser_expense_context_lens_v1`.
- Nature and context/person remain separate dimensions.
- Periods include 12 months, year, since 2023 and since 2013 where supported.
- Read-only drilldown interaction is present.
- Existing expense invariant R$8.623.752,53 and analytical cache 3.860/3.860 remain unchanged backend invariants.

### Patrimônio
- Direct read path `lts_browser_wealth_detail_v1`.
- RSU vested detail, FGTS, CIPÓ 396 and Volvo financing surfaces are in the canonical route.

### Cartões
- Direct read path `lts_browser_card_history_coverage_v1`.
- Certified historical detail remains distinct from aggregate fallback.

### Atualizações / search / classification / documents
- Direct server-side transaction search via `lts_browser_transactions_v1`.
- Total-result handling and Excel-compatible CSV export are implemented in the canonical frontend.
- Classification lifecycle wiring uses `lts_browser_semantic_feedback_v1` followed by product refresh/read verification with `lts_browser_product_v1`.
- Document lifecycle surface uses `lts_browser_document_lifecycle_v1`.
- Real authenticated classification and document interpretation E2E remain unclaimed/pending.

## Planning / FGTS audit closed for the current contract
Current audited backend evidence under no-future-FGTS-accrual rule:
- bank cash: R$15.794,43;
- D0: R$42.929,50;
- vested D+3: R$12.909,65;
- liquidity through D+3: R$71.633,58;
- documentary FGTS contingency: R$22.432,31, D+30, no future accrual;
- FGTS request-by date: 30/11/2026;
- management/action point: 30/12/2026;
- first uncovered gap: 30/01/2027;
- worst before FGTS: -R$25.782,39;
- worst after current documentary FGTS: -R$3.350,08.

Migration `dashboard_planning_first_negative_alias` normalized the first-negative field alias consumed by the frontend without changing financial arithmetic. The management/action date and first uncovered gap are therefore explicitly distinct under the current audited rule.

Historical R$3.700/month FGTS accrual logic and dependent R$32.309,05 figures remain historical-only and are not current forecast inputs.

## CIPÓ 396 evidence refinement
Actual consortium ledger evidence recovered:
- 12/02/2023 — R$6.654,50 — Bradesco;
- 15/03/2023 — R$6.502,70 — Bradesco;
- 17/04/2023 — R$6.502,70 — Itaú;
- 12/05/2023 — R$6.654,50 — Itaú;
- 15/05/2023 — R$151,80 — Itaú;
- 12/06/2023 — R$6.502,70 — Itaú.

Therefore R$6.654,50 is an actual standalone consortium entry and R$151,80 is a separate later entry; they must not be represented as same-date documentary arithmetic. The R$303,60 CIPÓ/consortium delta remains unresolved: matches recovered at that value were Visa Infinite rows and are not valid consortium evidence.

Still unresolved for CIPÓ: condominium source/formula/cutoff; raw R$1.780.358 gap; dedup R$1.312.268 gap; duplicate excess R$3.531,70; no fabricated post-2029 TR; market-minus-cost is not automatically taxable/net gain.

## Open dependencies preserved
- Authenticated physical-iPhone financial/data E2E of the canonical app.
- Real authenticated classification save → refresh → resolved disappearance/self-heal.
- Real authenticated PDF/image interpretation → review.
- Natural-liquidity authenticated save → refresh → visible.
- Append-only auditable cancellation/reversal semantics before enabling reversal UI.
- Evidence-only reduction of `A classificar` and further expense decision insights.
- Mastercard/Visa documentary recovery only from evidence.
- RSU historical R$578,68 sale difference remains unexplained/unitemized.
- CIPÓ unresolved items listed above, including R$303,60 delta.
- Volvo exact trim/version and km before valuation refinement.
- Open Finance written pricing/support/SLA/product×bank coverage; no provider/consent/spend/credential commitment without explicit user approval.
- Historical dependency audit back to 07/07/2026.
- Public root promotion only after explicit user authorization.

## User action now
NONE. Continue autonomous implementation and documentary/reconciliation work until a genuine user decision or authenticated physical-device gate is the blocker.
