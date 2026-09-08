# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current canonical baseline — 08/09/2026 04:42 BRT
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Fixed homologation manifest selects **CANONICAL v1.8 · Unified Expenses Decision Workbench** through `canonical-app.html`, exact product package `870acc37f220592c77b488be32315af284b52427`, exposure `352a4fe9716bff063a67dae2e01a0f484d6ac80e`.
- Canonical frontend is a single application; no v150/v151/v156/v160 iframe/wrapper chain is part of the primary product.
- Current gated modules: `canonical-liquidity-core.js`, `canonical-flow-v157.js`, `canonical-product-v157.js`, `canonical-presentation-v157.js`, `canonical-capabilities-v161.js`.
- Modular recovery gate `34170935882` and permanent canonical gate `34171231918`: **SUCCESS** in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Active/canonical/main candidate smokes `34170935887` / `34171231935` / `34171338575` and Pages `34171338335`: **SUCCESS**.
- Post-manifest active/canonical/main candidate smokes `34171452083` / `34171452913` / `34171453488` and Pages `34171452759`: **SUCCESS**.
- Dashboard Pass 5 recovery `34173223977` and permanent canonical gate `34173482173`: SUCCESS; final active/canonical/main smokes and Pages are green.
- Future-JWT recovery `34174520963`, permanent canonical gate `34174620205`, active/canonical/main smokes and Pages are SUCCESS; WebKit explicitly covers persisted future-token recovery.
- Post-exposure active/canonical/main smokes `34175144495` / `34175143351` / `34175143758` and Pages `34175143251`: SUCCESS.
- Briefing-capability recovery/candidate `34179625830` / `34179625805`, canonical gate/candidate `34179823179` / `34179823167`, main candidate/Pages `34179954294` / `34179953893`: SUCCESS.
- Dashboard Pass 6 recovery/candidate `34185954453` / `34185954506`, canonical gate/candidate `34186087590` / `34186087628`, main candidate/Pages `34186301851` / `34186300869`: SUCCESS.
- Post-exposure active/canonical/main smokes `34186663110` / `34186664337` / `34186664887` and Pages `34186664347`: SUCCESS.
- Route/receipt recovery/candidate `34190659782` / `34190659780`, canonical gate/candidate `34191017877` / `34191017858`, main candidate/Pages `34191216218` / `34191215874`: SUCCESS.
- Route/receipt artifact `10042106418`, digest `sha256:69ef7f8af36374e9c91ae5074690d13525676d8fe8ee326024c40e381e36ed47`: unified receipt plus Chromium/WebKit evidence.
- Post-v1.7-exposure active/canonical/main smokes `34191461669` / `34191462282` / `34191463017` and Pages `34191462402`: SUCCESS.
- Unified-expenses active gate/candidate `34199824400` / `34199824442`, canonical gate/candidate `34200253901` / `34200253918`, post-manifest active/canonical smokes `34200631320` / `34200627680`, main candidate/Pages `34200706521` / `34200704967`: SUCCESS.
- The expense gate now proves one visible owner plus month/year history, nature × context, `Não atribuído` meaning and item/month drilldown in Chromium/WebKit.
- Browser verification of the fixed URL resolved to `canonical-app.html?homologacao=e618ef48e22872ce718c7932872e2316e5660f67#Dashboard` and rendered `canonical-liquidity.js?v=20260908-continuity7`, truthful login, zero unauthenticated KPI cards and no iframe.
- Current immutable evidence: `backups/CANONICAL_APP_V18_UNIFIED_EXPENSES_CHECKPOINT_2026-09-08.md`.
- Durable briefing/decision map: `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated physical-iPhone visual/data E2E: PENDING / NOT CLAIMED.

## Route/session continuity + unified receipt gate
- The intended route is resolved before the first RPC/render and stored as navigation state only in `sessionStorage`; no financial value is persisted there.
- Refresh, signed-out login, future-JWT reset, browser back/forward, direct deep links and bfcache preserve or safely canonicalize the intended route.
- Invalid routes fall back to Dashboard; Central de Gestão restores one of eight allowlisted panes after refresh/back.
- The permanent browser run emits `lts-canonical-definition-of-done-receipt-v1`, covering the recovered product requirements in one machine-readable artifact.
- A deterministic `PASS` is distinct from final delivery: the receipt keeps authenticated real data, authenticated writes, physical iPhone and public-root promotion explicitly open/not claimed.

## Briefing capability recovery gate
- Central de Gestão mounts once inside `Atualizações`; no seventh primary mobile route is introduced.
- Ten required capabilities are visible and reachable: Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.
- Eight management panes are physically exercised in Chromium desktop and WebKit mobile.
- Planning displays first insufficiency, worst position and FGTS guardrail without projecting new FGTS accrual.
- Recurrence audit exposes covered/review sets and never converts frequency into an automatic fact.
- Vesting scenario is read-only; reconciliation preserves the R$0 acceptance criterion.
- Executive JSON and recurrence CSV exports are present; fixture mode blocks backup export and restore writes.
- Real restore path requires client checksum verification, backend staging/preview, exact phrase and a second confirmation; it remains unclaimed with real authenticated data.
- Settings exposes provider-neutral Open Finance state; provider, consent and spend remain explicit future decisions.

## Dashboard Fidelity Pass 6 gate
- Desktop navigation follows the approved-reference intent order while the mobile bar remains exactly six destinations; `Receitas` aliases the evidenced Flow and does not invent a separate financial source.
- Month/as-of controls and the `Hoje` reload are visible and physically exercised.
- Five evidence-labelled signals distinguish account count, D0, D+3, FGTS D+30 and a month comparison only when certified.
- Bank position rows and decision panels open real product routes; Planning opens the corresponding Central de Gestão pane.
- The permanent browser gate covers both Chromium 1312×1199 and WebKit 390×844, including all v1.6 management panes.
- A delayed remount race discovered by the canonical gate was fixed so a mobile scenario selection is not discarded before calculation.

## iPhone session recovery gate
- Real-device symptom: fatal surface disclosed `JWT issued at future` instead of recovering or renewing the session.
- Canonical RPC path now retries once after a short clock-skew delay, coalesces one token refresh, then safely clears an unrecoverable cached session and returns to login.
- WebKit 390×844 proves session removal, `jwt-clock` recovery status, safe guidance and absence of raw JWT detail.
- This deterministic gate closes the reproducible failure class; it does not substitute for the final authenticated physical-iPhone data E2E.

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
- Atualizações includes compact action center, server-side transaction search, total, Excel-compatible CSV, classification lifecycle wiring, document lifecycle visibility and reviewed bank↔cash-investment Aplicar/Resgatar.
- Liquidity movement UI never guesses account or asset, previews both legs, shows economic effect R$0, requires explicit confirmation and re-reads product/cockpit after a real write.
- Missing evidence remains unavailable; no merchant/category/account/valuation/competence is invented.
- No iframe, `document.write`, permanent `setInterval` or `MutationObserver` in the canonical product.
- Public `index.html` remains unchanged.

## Exact deterministic evidence
Current route/receipt recovery gate `34190659782` and permanent canonical gate `34191017877`: **SUCCESS**. Dashboard Pass 6, V157+ and v1.6 capability evidence remains preserved.

Validated in Chromium desktop 1312×1199 and WebKit mobile 390×844:
- five KPI cards populated under controlled fixture;
- all six physical routes and return to Dashboard;
- Fluxo supports Consolidado/Itaú/Bradesco/C6, 10 presets, 14 desktop columns, account switching and expandable movements without technical labels;
- Despesas nature × context, drilldown and period selector;
- Patrimônio / FGTS surface;
- Cartões surface;
- Atualizações classification queue, incremental Mastercard search, result total, CSV enablement and document lifecycle area;
- Aplicar/Resgatar card mounts exactly once;
- application preview accepts `5 mil` and shows equal/opposite bank/asset legs with economic effect R$0;
- fixture writer remains disabled, preventing accidental financial mutation;
- no iframe;
- no horizontal overflow;
- six-item mobile navigation not clipped;
- no browser page errors;
- no-fixture unauthenticated state exposes the actual login rather than a fake financial Dashboard.
- all ten recovered briefing capabilities and eight management panes behave in both browsers;
- visual artifacts include Dashboard, Flow, Despesas, Patrimônio, Cartões, Atualizações and management Planning in desktop/mobile.

These are deterministic fixture/unauthenticated gates. They do not prove the user's authenticated physical-iPhone session and must not be represented as authenticated E2E.

## Dashboard visual fidelity — protected Pass 6 baseline / remaining P0
The approved original 1312×1199 image remains authoritative for presentation hierarchy/density. Pass 6 closes the largest structural gaps: navigation breadth, month/as-of controls, five evidence-labelled cards, bank position and working drill-downs. Pixel-perfect parity, richer evidence-backed historical chart detail and real authenticated data presentation remain open; the reference image is never a source of financial facts.

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
- Previous snapshot at 18/08/2026: **459,483 shares / R$32.772,30**; historical only, not the current vested KPI.
- Current evidence metadata records a reduction of 275 shares after the prior snapshot and a user-confirmed sale, but exact trade settlement date/price/proceeds for that reduction remain pending documentary reconciliation.
- Brokerage cash of R$2.862,67 at 03/09/2026 is separately recorded as `available_unclassified` and excluded from D0/D3 until transfer latency is evidenced.
- Do not recreate an unsupported quantity/gross/fee/FX breakdown for historical sale proceeds.

## Append-only mutation / cancellation contract
Backend contract remains proven for edit/cancel/split behavior:
- source `financial_events` / legacy facts are not destructively updated or deleted;
- current-event operations are appended to `lts_flow_event_operation`;
- legacy overrides are appended to `projecao_op`;
- mutations are recorded in `lts_flow_mutation_audit`;
- effective readers apply the latest active operation and suppress cancelled/split originals appropriately;
- `lts_fix86_legacy_guardrails_qa_v4` passes **10/10**, including `flow_mutations_append_only_operational`.

A separate user-facing **undo/reversal** action is not claimed or enabled until an explicit append-only reversal contract exists.

## CIPÓ 396 evidence state
- Actual consortium entries establish R$6.654,50 on 12/05/2023 and a separate R$151,80 entry on 15/05/2023; they must not be presented as same-date arithmetic evidence.
- The R$303,60 consortium delta remains unresolved; R$303,60 rows recovered in the ledger are Visa Infinite and are not valid consortium evidence.
- Condominium source/formula/cutoff remains absent.
- Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70 remain unresolved.
- Never fabricate post-2029 TR and never automatically treat market-minus-cost as taxable/net gain.

## Open blockers retained
- Authenticated physical-iPhone financial/data E2E of the canonical app when real-device evidence becomes the final gate.
- Unified receipt authenticated-real and physical-device rows remain OPEN; `gate_status: PASS` is not final product-delivery approval.
- Real authenticated liquidity save → refresh → visible; deterministic fixture never posts financial facts.
- Real authenticated classification save → refresh → resolved disappearance/self-heal.
- Real authenticated PDF/image interpretation → review.
- Real authenticated server-side search/CSV E2E.
- User-facing reversal/undo remains disabled until an explicit append-only reversal contract is implemented.
- Evidence-only reduction of `A classificar` and further expense decision insights.
- Mastercard/Visa documentary gaps; never pattern-fill.
- Historical RSU sale detail where evidence is incomplete.
- CIPÓ unresolved items listed above.
- Volvo exact trim/version and km before valuation refinement.
- Open Finance written pricing/support/SLA/product×bank coverage for Itaú/Bradesco/C6; no consent/spend/credential/provider commitment without explicit user decision.
- Supabase database hardening is closed at migration `20260908045049`: 13/13 audited tables use deny-by-default RLS, 12/12 arbitrary-user helpers are internal-only, guarded browser RPCs retained authenticated access and transactional contract regression passed. Leaked-password protection remains a separate controlled Auth-setting review.
- Continue historical dependency audit back to 07/07/2026.
- Public promotion only after explicit user approval.
