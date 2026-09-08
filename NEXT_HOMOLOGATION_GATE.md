# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current canonical baseline — 08/09/2026 10:15 BRT
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Fixed homologation selects **CANONICAL v1.11 · Layered Liquidity** through `canonical-app.html`, exact product `8a9c675ed3940da19a10c04e56249a315576045a`, exposure `04c051f19167e913079bb8e75b692f5fe430892c`; public `index.html` is unchanged.
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
- Canonical v1.9 recovery/candidate `34219446266` / `34219446256`, canonical gate/candidate `34219669569` / `34219669492`, main candidate/Pages `34219911180` / `34219909612`: SUCCESS.
- Post-exposure active/canonical/main smokes `34220841617` / `34220895671` / `34220950755` and Pages `34220949477`: SUCCESS.
- V1.9 evidence artifacts: recovery `10053154126` / `sha256:711c1d2d19d558d9caf6d0cd40bdddc47416b344353851ed8884344e7d355a17`; canonical `10053239237` / `sha256:fdc1d83505d2ccd1cf8529aec088518e42e344115c24c7c13eb3f789f01e6a0f`.
- Fixed-URL live verification resolved to `canonical-app.html?homologacao=6aba220…`, loaded Flow asset `?v=20260908-flow-parity9`, truthful login and no iframe/fixture financial content.
- V1.10 recovery gate/smoke `34225155424` / `34225155422`, canonical gate/smoke `34225365210` / `34225365141`, main smoke/Pages `34225542803` / `34225541791`: SUCCESS.
- V1.10 post-exposure active/canonical/main smokes `34225917363` / `34225967201` / `34226016981` and Pages `34226016118`: SUCCESS.
- V1.10 artifacts: recovery `10055417140` / `sha256:46b285161dd778294e9d5161bbe6faa71d96e7bb31188b6b25bcc5adb608e33b`; canonical `10055499807` / `sha256:a255c1a04e8a5b7f33ef5a199ad3b24c34fdd1bf8ed7f05245026f520373a841`.
- Fixed-URL live verification resolved to `canonical-app.html?homologacao=de4362d…#Dashboard`, loaded `canonical-liquidity.js?v=20260908-dashboard-truth10`, truthful signed-out login, zero iframe and no unauthenticated fixture Dashboard.
- V1.11 recovery gate/smoke `34229899061` / `34229899074`, canonical gate/smoke `34230146792` / `34230146827`, main smoke/Pages `34230384306` / `34230382218`: SUCCESS.
- V1.11 post-exposure active/canonical/main smokes `34230610235` / `34230659383` / `34230705729` and Pages `34230705397`: SUCCESS.
- V1.11 artifacts: recovery `10057369616` / `sha256:5939e41b70411530e1668546d83764ea48454e72598e0c1e7dc967a0414e87d2`; canonical `10057455711` / `sha256:b3cea9b02272be1495797ed8151fadcda8c3e865929729d648c12e43017aea34`.
- Fixed-URL live verification resolved to `canonical-app.html?homologacao=8a9c675…#Dashboard`, loaded `canonical-liquidity.js?v=20260908-dashboard-layers11`, truthful signed-out login, zero iframe and no unauthenticated fixture Dashboard.
- Current immutable evidence: `backups/CANONICAL_APP_V111_LAYERED_LIQUIDITY_CHECKPOINT_2026-09-08.md`.
- Durable briefing/decision map: `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated physical-iPhone visual/data E2E: PENDING / NOT CLAIMED.

## Canonical v1.11 Layered Liquidity — selected for fixed exposure
- Exact base is the v1.10 closure `a4a19217dd59d83784537d623e58eeaf4d2befb2`; no public-root change and no wrapper reintroduction.
- Dashboard contract `reference-layered-liquidity-commitments-v3` adds `current-base-scheduled-rsu-restricted-fgts-v1` while preserving `fact-before-asof-projection-after-asof-v1` and `product-commitments-plus-card-due`.
- Current evidenced position is anchored from cockpit `through_d3`; future base uses `current_liquidity_balance`, scheduled RSUs use `conditional_rsu_balance`, and FGTS contingency uses `restricted_total_balance` only after the documented D+30 boundary.
- Two charts, four legends/composition semantics, exact point counts and panel-height bounds are gated in desktop Chromium and mobile WebKit. The gate caught and blocked an FGTS CSS-class collision before release.
- V150/V151+ Flow interactions, v1.10 commitment separation, all six routes, Central de Gestão, route/session recovery and truthful unauthenticated state remain in the same regression suite.
- Authenticated real-data/write and physical-iPhone evidence remain OPEN / NOT CLAIMED.

## Canonical v1.10 Dashboard Decision Truth — protected predecessor
- Exact base is v1.9 closure `3858739e73ebdedffbe06766c05fdbc9c59f91d6`; no public-root change and no wrapper reintroduction.
- Dashboard contract is `reference-fact-projection-commitments-v2`: both liquidity charts render observed position through `as_of` separately from a dashed later projection, with explicit legend, accessible label and horizon labels.
- `Próximos Compromissos` consumes only the next card invoice plus `product.commitments.commitments` rows carrying an explicit `next_due`. `work.top_actions` stays in `Atualizações` and cannot leak into the commitment panel.
- Commitment rows and “Ver todos” physically navigate to `Fluxo Diário`; the gate returns to Dashboard and rechecks route ownership/readiness.
- Local Chromium and recovery/canonical CI Chromium+WebKit are PASS at 1312×1199 and 390×844, including the unchanged V150 Flow parity suite, all six routes, dashboard reload/drill-downs, mobile overflow and truthful unauthenticated state.
- Exact product and exposure were promoted by normal no-force fast-forward; all pre/post-exposure smokes and Pages are PASS, and the fixed URL has been verified on the V1.10 asset.
- Authenticated real-data/write and physical-iPhone evidence remain OPEN / NOT CLAIMED.

## Canonical v1.9 Flow-parity baseline — selected for fixed exposure
- Release audit proves V150–V152 retained the rich Flow and V153 was the material simplification point; V154–V160 remain valuable evidence for later visual/data/session improvements.
- Candidate contract `v150-validated-flow-plus-v157-liquidity-v1` ports approved interactions into the single canonical frontend without bringing back a wrapper.
- Restored: Hoje, exactly five future days, scroll preservation, semantic movement/transfer/net-salary labels, inline reconciled card-invoice summary/full detail and append-only edit/duplicate/split/cancel.
- Preserved: `lts_browser_flow_v8`, four account views, ten periods, 14 consolidated liquidity/economic layers and mobile liquidity cards.
- Local deterministic Chromium desktop/mobile, branch CI Chromium/WebKit, post-manifest smokes and Pages are PASS, including fixture write denial and Flow-specific mobile overflow. Authenticated real-data/write and physical-iPhone proof remain separate and open.

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
