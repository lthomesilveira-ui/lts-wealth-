# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current canonical baseline — 06/09/2026
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Fixed homologation manifest selects **canonical-v1** through `canonical-app.html`.
- Canonical frontend is a single application; no v150/v151/v156/v160 iframe/wrapper chain is part of the primary product.
- Functional canonical app source commit: `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`.
- Fixed homologation exposure commit on `main`: `e6f3ab7421d5b7cb1986df768835f9d826536d9d`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated physical-iPhone visual/data E2E: PENDING / NOT CLAIMED.
- Current immutable evidence: `backups/CANONICAL_APP_V1_FUNCTIONAL_HOMOLOGATION_CHECKPOINT_2026-09-06.md`.

## Why the canonical line supersedes v160
- Real-iPhone evidence repeatedly rejected wrapper-based releases because presentation, data readiness and navigation could not be made reliable together.
- The canonical line removes that failure mode: one frontend owns authentication/session, Dashboard, data access and all six routes directly.
- v154–v160 remain historical evidence/fallback knowledge only; they are not the primary product architecture.

## Canonical product contract
- Official-reference visual language and compact executive density.
- Liquidity-first KPIs: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
- Direct authenticated Supabase/RPC data access; no synthetic user-facing financial values and no false zero fallback.
- Six routes owned by the same app: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Fluxo Diário supports Consolidado, Itaú, Bradesco and C6.
- Despesas keeps nature distinct from context/person and supports read-only drilldown/historical periods.
- Patrimônio consumes current wealth detail, including RSU, FGTS, CIPÓ 396 and Volvo surfaces where evidence exists.
- Cartões distinguishes certified detail from aggregate fallback.
- Atualizações includes compact action center, server-side transaction search, total, Excel-compatible CSV, classification lifecycle wiring and document lifecycle visibility.
- Missing evidence remains unavailable; no merchant/category/account/valuation/competence is invented.
- No iframe, `document.write`, permanent `setInterval` or `MutationObserver` in the canonical product.
- Public `index.html` remains unchanged.

## Exact deterministic evidence
Canonical functional gate run `34003647351`: **SUCCESS**.

Validated in Chromium desktop 1312×1199 and WebKit mobile 390×844:
- five KPI cards populated under controlled fixture;
- all six physical routes and return to Dashboard;
- Fluxo account switching;
- Despesas nature × context, drilldown and period selector;
- Patrimônio / FGTS surface;
- Cartões surface;
- Atualizações classification queue, incremental Mastercard search, result total, CSV enablement and document lifecycle area;
- no iframe;
- no horizontal overflow;
- six-item mobile navigation not clipped;
- no browser page errors;
- no-fixture unauthenticated state exposes the actual login rather than a fake financial Dashboard.

Gate artifact: `9980249754`, digest `sha256:10aaad7ea9b27920562d32ce69462249fdd3d03818caffe2fe3d985527b6b5e0`.

Exact GitHub Pages deployment for canonical homologation exposure: run `34003976631` — **SUCCESS**.

These are deterministic fixture/unauthenticated gates. They do not prove the user's authenticated physical-iPhone session and must not be represented as authenticated E2E.

## Current Planning / FGTS invariant
Current audited contract under the conservative no-future-accrual rule:
- bank cash: R$15.794,43;
- D0: R$42.929,50;
- vested D+3: R$12.909,65;
- liquidity through D+3: R$71.633,58;
- documentary FGTS: R$22.432,31 at 21/08/2026, restricted / approximately D+30, never D+3;
- future FGTS accrual estimation: **disabled**;
- FGTS request-by date: **30/11/2026**;
- management/action point: **30/12/2026**;
- first uncovered gap: **30/01/2027**;
- worst before FGTS: -R$25.782,39;
- worst after current documentary FGTS: -R$3.350,08.

Migration `dashboard_planning_first_negative_alias` normalizes the first-negative field consumed by the frontend without changing financial arithmetic. Historical R$3.700/month accrual and dependent R$32.309,05 figures are historical evidence only.

## Current RSU evidence
- Current documentary position at 03/09/2026: **184,483 Organon shares / R$12.909,65 / D+3**.
- Previous snapshot at 18/08/2026: **459,483 shares / R$32.772,30**; it is historical, not the current vested KPI.
- Current evidence metadata records a reduction of 275 shares after the prior snapshot and a user-confirmed sale, but exact trade settlement date/price/proceeds for that reduction remain pending documentary reconciliation.
- Brokerage cash of R$2.862,67 at 03/09/2026 is separately recorded as `available_unclassified` and excluded from D0/D3 until transfer latency is evidenced.
- Do not recreate an unsupported quantity/gross/fee/FX breakdown for historical sale proceeds.

## Append-only mutation / cancellation contract
Backend contract is now considered proven for edit/cancel/split behavior:
- source `financial_events` / legacy facts are not destructively updated or deleted;
- current-event operations are appended to `lts_flow_event_operation`;
- legacy overrides are appended to `projecao_op`;
- mutations are recorded in `lts_flow_mutation_audit`;
- effective readers apply the latest active operation and suppress cancelled/split originals appropriately;
- `lts_fix86_legacy_guardrails_qa_v4` passes **10/10**, including `flow_mutations_append_only_operational`.

This closes the open requirement for append-only cancellation/edit/split semantics. A separate user-facing **undo/reversal** action is not claimed or enabled until an explicit append-only reversal contract exists.

## CIPÓ 396 evidence state
- Actual consortium entries establish R$6.654,50 on 12/05/2023 and a separate R$151,80 entry on 15/05/2023; they must not be presented as same-date arithmetic evidence.
- The R$303,60 consortium delta remains unresolved; R$303,60 rows recovered in the ledger are Visa Infinite and are not valid consortium evidence.
- Condominium source/formula/cutoff remains absent.
- Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70 remain unresolved.
- Never fabricate post-2029 TR and never automatically treat market-minus-cost as taxable/net gain.

## Open blockers retained
- Authenticated physical-iPhone financial/data E2E of the canonical app when real-device evidence becomes the final gate.
- Real authenticated classification save → refresh → resolved disappearance/self-heal.
- Real authenticated PDF/image interpretation → review.
- Authenticated natural-liquidity save → refresh → visible.
- User-facing reversal/undo remains disabled until an explicit append-only reversal contract is implemented; append-only cancel/edit/split semantics themselves are proven.
- Evidence-only reduction of `A classificar` and further expense decision insights.
- Mastercard/Visa documentary gaps; never pattern-fill.
- Historical RSU sale detail still lacks a complete documentary breakdown where not evidenced.
- CIPÓ unresolved items listed above.
- Volvo exact trim/version and km before valuation refinement.
- Open Finance written pricing/support/SLA/product×bank coverage for Itaú/Bradesco/C6; no consent/spend/credential/provider commitment without explicit user decision.
- Continue historical dependency audit back to 07/07/2026.
- Public promotion only after explicit user approval.
