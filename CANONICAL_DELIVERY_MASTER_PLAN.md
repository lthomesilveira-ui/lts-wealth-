# LTS Wealth — Canonical Delivery Master Plan

Last refreshed: 2026-09-08 18:50 BRT
Active implementation branch: `canonical-v157plus-product-recovery` (canonical v1.19 product `37781c3b11389789716781accca6c1fdabea461c`; product tree `626437edfa47d12be4a061f3ff6c88e077ae2304`; fixed-manifest exposure `59222846a5c7e67c923790da9ad4088df9781fa4`; all release branches aligned by normal no-force fast-forward)

Purpose: this is the execution-order view of the LTS Wealth backlog. It does not replace documentary evidence or immutable checkpoints. `PROJECT_MASTER_BACKLOG.md` remains the complete persistent dependency list. This file makes the remaining work explicit so product delivery does not get lost behind release mechanics.

Current milestone: canonical v1.19 preserves the complete v1.18→v1.9 line and closes the executable holistic UX pass without changing financial truth. The approved 1312×1199 Dashboard, responsive 390×844 product, safe-error boundary, accessibility states, permanent Chromium/WebKit gates, all pre/post-exposure smokes and Pages are green; the fixed URL resolves to the exact v1.19 product. Only authenticated real lifecycles and physical-device evidence remain P0 execution gates.

## Definition of DONE for the app
The LTS Wealth app is not considered delivered until all P0 items below are complete together in one canonical application:
- daily use can replace the Excel without re-entering existing data;
- past, today and next-90-day Flow is consistent and cards, recurrences, commitments, transfers, simulations and reconciliation remain integrated;
- one canonical frontend, not a wrapper/iframe chain over historical releases;
- Dashboard visually aligned with the approved official reference;
- real authenticated financial data rendered without fabricated values or false zeros;
- desktop and mobile responsive layouts designed intentionally, not desktop squeezed into mobile;
- six working product routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações;
- authentication/session state works in the same application;
- no sustained freeze, route trap, clipping or hidden historical UI;
- deterministic desktop + WebKit gates pass before real-device homologation;
- physical-iPhone material homologation is not claimed until actually evidenced.

## P0 — Deliver the canonical app
### P0.1 Canonical shell / architecture
- [x] Replace the v150/v151/v156/v160 wrapper/frame chain with one canonical app shell.
- [x] Connect directly to the existing authenticated data/RPC layer.
- [x] Preserve backend, financial rules, history, classification rules and documentary evidence.
- [x] Remove historical release branding/UI from the primary product surface.
- [x] V1.17 product-language guard removes fixed build badges and technical release labels from every normal route while retaining internal diagnostics.
- [x] Add explicit loading, unauthenticated, error and data-ready states.

### P0.2 Dashboard — approved visual contract
- [x] Build the Dashboard directly against the approved 1312×1199 official reference; Pass 6 plus V1.15/V1.19 close material structural hierarchy, density and responsive behavior. Literal pixel identity is not asserted as a financial/product fact.
- [x] Desktop Pass 6: dark left rail, approved-reference intent order, light dense executive canvas, compact spacing and month/as-of toolbar.
- [x] Mobile: purpose-built responsive hierarchy; no squeezed desktop canvas.
- [x] Five primary KPIs: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês).
- [x] Real values only; missing evidence stays unavailable, never false R$0,00.
- [x] Dense executive sections: working hierarchy, bank rows and decision drill-downs exist.
- [x] Decision truth v1.10: observed liquidity through `as_of` is visually distinct from the dashed later projection and does not imply that forecast points are facts.
- [x] `Próximos Compromissos` is sourced only from the next card invoice and contractual rows with explicit `next_due`; review/classification/planning tasks remain in `Atualizações`.
- [x] Layered liquidity v1.11: current anchor from cockpit `through_d3`, base projection, scheduled-vesting conditional scenario and restricted FGTS scenario remain visually and semantically separate.
- [x] Four current-composition labels expose accounts, D0/D1, vested RSUs and restricted FGTS without summing conditional/restricted scenarios into current cash.
- [x] Preserve evidence-backed historical chart/detail fidelity without synthetic values; authenticated real-data proof remains tracked separately in P0.4/P5.
- [x] Expense/category route drill-down from Dashboard where evidence exists.
- [x] V1.16 first-negative/management contract: dates are displayed separately and prominently when different; a chart marker requires an exact evidenced negative horizon row and is never interpolated.
- [x] FGTS rule preserved: R$22.432,31 at 21/08/2026, restricted ~D+30, never D+3, no future accrual projection.

### P0.3 Navigation / responsive product
- [x] One router owned by the canonical app.
- [x] All six routes work physically on desktop and mobile.
- [x] Mobile nav shows all six destinations with no clipping/overflow.
- [x] Route state survives refresh/session restoration, signed-out login, future-JWT reset, direct links, browser back/forward and bfcache; invalid routes fall back safely.
- [x] Persisted future-issued JWT receives bounded retry/refresh and safe login reset without raw error disclosure.
- [x] Financing, Planning, Revenues/Inputs, Recurrences, Commitments, Simulations, Reconciliation, Reports, Documents and Settings are discoverable in Central de Gestão inside `Atualizações`, while mobile keeps exactly six primary routes.
- [x] No iframe navigation races or hidden historical route owners.

### P0.4 Authentication + real data
- [x] Canonical app owns login/session presentation.
- [x] Same authenticated session feeds Dashboard and all modules.
- [x] Direct read paths for cockpit, flow, expenses, wealth, cards, updates/search.
- [x] No synthetic financial data for visual QA outside explicit fixtures.
- [x] Error state must be visible and diagnosable instead of silently showing dashes.
- [x] Future-issued cached JWT recovery is explicit, bounded and covered in mobile WebKit.
- [ ] Authenticated physical-iPhone post-fix financial/data E2E.

### P0.5 Product-level QA before asking the user
- [x] Desktop structural visual gate against approved reference hierarchy/density; pixel-perfect comparison remains separate and unclaimed.
- [x] Mobile WebKit gate for layout, scrolling, route fit and event-loop responsiveness.
- [x] Six-route physical navigation regression.
- [x] No-horizontal-overflow and no-sustained-DOM-churn checks.
- [x] Auth-truth / missing-data truth checks.
- [x] One machine-readable `lts-canonical-definition-of-done-receipt-v1` maps the recovered requirements and separates automatic PASS from authenticated-real/physical-device claims.
- [x] Fixed homologation manifest selects exact green canonical v1.19 product `37781c3b…` through exposure `59222846…`; public promotion remains separate and unauthorized.

### P0.6 Supabase security hardening
- [x] Inventory the 13 `public` tables currently reported with RLS disabled.
- [x] Verify exact direct privileges: neither `anon` nor `authenticated` has SELECT or INSERT/UPDATE/DELETE on those 13 tables; no direct client-table exposure was demonstrated.
- [x] Map client-executable SECURITY DEFINER functions: 12 arbitrary-user internal helpers closed; remaining signed-in functions have a direct allowlist/JWT/user guard and are intended browser contracts.
- [x] Enable deny-by-default RLS on all 13 internal tables without adding direct browser policies or breaking owner-executed read caches.
- [x] Apply migration `20260908045049` as one bounded package; preserve `service_role`, secure future object defaults and pass authenticated Flow/Dashboard/product regression inside rollback.
- [x] Recheck Security Advisor and exact catalog postconditions: no RLS-disabled or anonymous SECURITY DEFINER findings; zero authenticated SECURITY DEFINER functions lacking a direct guard under the audited rule.
- [ ] Review and enable leaked-password protection under a controlled Auth change window.

### P0.7 Holistic UX closure
- [x] Audit the whole application against the official Dashboard model, the recovered Homologação/Execução decisions and the validated V150–V151+ behavior floor.
- [x] Remove duplicated actions and technical language, improve hierarchy/interaction consistency and preserve financial truth/auditability; sparse real-data routes keep truthful states rather than decorative filler.
- [x] Gate loading/empty/error truth and translate raw provider/session/backend errors into safe guidance while retaining bounded internal diagnostics.
- [x] Re-run visual comparison at 1312×1199 and responsive review at 390×844 after the coherent V1.19 UX package.
- [x] Record UX decisions and rejected alternatives in `backups/CANONICAL_APP_V119_UX_CLOSURE_CHECKPOINT_2026-09-08.md`.

## P1 — Core functional modules in the canonical app
### P1.1 Fluxo Diário
- [x] Canonical UI for Itaú, Bradesco, C6 and Consolidado.
- [x] Preserve Saldo anterior | Entradas | Saídas | Saldo final hierarchy.
- [x] Facts > projections; scenarios never facts; stale anchors cannot reanchor.
- [x] V150 parity restored on the canonical line: Hoje, complete next-five-day view, scroll preservation and semantic movement labels.
- [x] Card-payment rows open reconciled invoice summary/full detail inline and do not duplicate underlying expenses.
- [x] Projection actions expose append-only edit, duplicate, split/replace and cancel with 2–12 validated parts and visible sum.
- [x] Bank↔liquidity-asset transfers have consolidated economic effect zero.
- [x] Historical bank is never inferred without evidence.
- [ ] Close real authenticated invoice and mutation readback plus physical-iPhone evidence.

### P1.2 Despesas
- [x] Bring the existing R$8.623.752,53 invariant and 3.860/3.860 analytical cache into the canonical UI.
- [x] Nature and context/person/cost center remain separate dimensions.
- [x] Current year, 12 months, since 2023 and since 2013 views where evidence exists.
- [x] Improve density, ranking and management-useful insights in one unified history/nature/context surface.
- [ ] Reduce `A classificar` only through evidence.
- [x] Explain each item/context with bidirectional lens drilldown and monthly item detail; missing evidence remains explicit.

### P1.3 Patrimônio
- [x] Canonical wealth summary and drilldowns.
- [x] RSU vested position and sale history with future awards excluded before vest/settlement.
- [x] FGTS temporal positions kept distinct.
- [x] CIPÓ 396 rich drilldown preserved without invented assumptions.
- [x] Volvo financing represented exactly once economically.

### P1.4 Cartões
- [x] Canonical card view using certified detail where available and aggregate fallback only where necessary.
- [x] No duplicate spend via invoice + underlying transactions.
- [x] Explicitly label incomplete documentary months rather than filling patterns.

### P1.5 Atualizações / Inputs
- [x] Compact prioritized checklist with no large blank gaps.
- [x] Evidence-backed category/context suggestions consistently throughout the list.
- [x] Explain why user input is needed where ambiguity remains.
- [x] Keep text-entry preview; never auto-post without explicit approval.
- [x] Date/value/account-or-card validation before approval.
- [x] V1.12 restores the missing rendered input surface with editable date/value/nature/account/card/category/context/counterparty/description, idempotent explicit writer confirmation and fixture write prohibition.
- [x] Central de Gestão groups ten recovered briefing capabilities without inflating the six-route mobile navigation.

## P2 — Search, classification, documents and write lifecycles
### P2.1 Transaction search
- [x] Finish server-side incremental search through `lts_browser_transactions_v1`.
- [x] Search while typing across supported history from 10/10/2013 plus future existing launches.
- [x] Read-only results with total count.
- [x] Excel-compatible CSV export preserving available date, description, account, direction, amount, category, counterparty, cost center and source/reference.
- [x] Existing evidence: Mastercard returns 239 rows spanning 01/11/2013 to 12/04/2028.

### P2.2 Classification lifecycle
- [x] Classification is the foreground action in `Atualizações`; documents/secondary work remain under collapsed `Outras ações que precisam de você` per V147.
- [ ] Real authenticated save → refresh → resolved disappearance / retry / `O que mudou`.
- [~] Evidence precedence stays: user decision > generated classification already accepted/evidenced > reconciliation link > bounded text rule > unclassified; raw source remains immutable.
- [ ] Public merchant research is shown only as a separate suggestion with confidence/evidence; it never proves purpose or silently promotes a classification.
- [ ] Marketplaces/intermediaries never determine purchase purpose alone.

### P2.3 Documents / interpretation
- [x] Guided type selection and explicit association UI implemented under `classification-first-guided-document-intake-v1`.
- [x] Private `lts-documents` upload + `lts_browser_register_document_v2` registration path implemented; cleanup is attempted if registration fails.
- [x] Same-route Documentos navigation opens the collapsed section without rerendering/erasing mounted Updates modules.
- [x] V1.14 restores the V149 read-only `v149-evidence-review-readonly-canonical-v1` surface: supplied association and extracted evidence are visibly separate, bounded/escaped and missing links are explicit.
- [x] Browser reader `lts_browser_document_review_queue_v1` and service-role-only internal read model are applied and gated; review exposes no control and cannot approve, reconcile, classify or post a fact.
- [ ] Real authenticated PDF/image upload → register → interpret → review/readback.
- [x] Bank statement association: institution/account + competence.
- [x] Card statement association: card + competence.
- [x] Financing association: commitment + exact as-of.
- [x] Filename never determines financial facts.
- [x] Upload alone never posts financial data.

### P2.4 Natural liquidity input / reversals
- [ ] Real authenticated save → refresh → visible result.
- [x] Preserve parser for 5 mil / R$5.000 / 5000 / 3k / R$1.250,50.
- [x] Never guess account/asset.
- [x] Preview both legs, before/after and economic effect R$0 before confirmation; fixture mode keeps the writer disabled.
- [ ] Define append-only auditable cancellation/reversal semantics before enabling reversal UI.

## P3 — Planning, reconciliation and documentary gaps
### P3.1 Planning / FGTS
- [x] Planning executive reader/UI uses the no-future-FGTS-accrual rule.
- [x] Display first-negative date separately from management/action date when different.
- [ ] Revalidate both dates through a real authenticated E2E against the current material dataset.
- [ ] Historical R$3.700/month FGTS projections remain historical only.

### P3.2 Cards historical recovery
- [~] Continue Mastercard/Visa documentary recovery only from evidence.
- [ ] Mastercard 2023 category matrix remains absent despite 12 ledger-only payments / R$496.689,05.
- [ ] Incomplete Mastercard 2022/2024/2025 months remain open.
- [ ] C6 Aug/2024 explicit R$66,70 gap remains visible.

### P3.3 CIPÓ 396
- [ ] Itaú consortium delta R$303,60.
- [ ] R$6.654,50 remains arithmetic-only from R$6.502,70 + R$151,80 on different dates.
- [ ] Condominium formula/cutoff source absent.
- [ ] Raw gap R$1.780.358.
- [ ] Dedup gap R$1.312.268.
- [ ] Duplicate excess through Jul/2026 R$3.531,70.
- [ ] No fabricated post-2029 TR.
- [ ] Market-minus-cost is not automatically taxable/net gain.

### P3.4 RSU / Volvo
- [ ] R$578,68 historical RSU sale difference remains unexplained/unitemized.
- [ ] Volvo exact trim/version and km required before valuation refinement.

### P3.5 Historical continuity
- [x] Audit dependencies back to project start 07/07/2026 through the two-month decision ledger, Git lineage and immutable checkpoints so prior improvements remain regression-protected.
- [x] Explain/correct the 01/01/2026 zero/negative balance behavior while preserving Realizado ≠ Projetado; real backend opening is derived from certified close minus daily net.
- [x] Verify the rejected 24/08 yellow band is absent without altering the validated `+` position/column order.
- [ ] Investigate the R$0,01 Bradesco difference and 06/08 Cofrinho event from source evidence.
- [ ] Keep the 12/08 Bradesco R$0,17 interval and Cofrinho R$186,10 timing as documentary gaps, not inferred facts.
- [x] Inventory original-workbook versus current-app snapshots for 31/12/2026 and 31/12/2029 without claiming equality across obsolete scenario layers; exact app coverage through 31/12/2029 plus D+30 is proven.
- [x] Consolidate the recovered two-month decision ledger in `backups/TWO_MONTH_FEEDBACK_RECOVERY_CHECKPOINT_2026-09-08.md`.

## P4 — Open Finance
Open Finance is still part of the product roadmap. It was not cancelled; work was interrupted by the unresolved app/frontend delivery problem.

### P4.1 What is already done
- [x] Provider-neutral private architecture QA 14/14.
- [x] No real consent, token or provider commitment has been made.

### P4.2 What still has to be done before choosing a provider
- [~] Obtain written pricing for viable providers.
- [~] Obtain support model and SLA.
- [~] Confirm product-by-bank coverage for Itaú, Bradesco and C6.
- [ ] Confirm the exact data scope needed: accounts, transactions, balances, cards/invoices and investments where available.
- [ ] Compare refresh cadence, historical depth, webhook/event support, consent renewal, error handling and sandbox quality.
- [ ] Produce a provider comparison with cost/coverage/operational tradeoffs.

### P4.3 Decision that genuinely belongs to the user
- [ ] Provider/commercial spend decision after evidence is assembled.
- [ ] Consent authorization when a provider is selected.
- [ ] No credentials, commercial commitment or spend before explicit approval.

### P4.4 Integration after provider decision
- [ ] Consent/onboarding flow inside canonical app.
- [ ] Normalize bank/account/card identities against LTS entities.
- [ ] Import balances/transactions read-only first.
- [ ] Reconciliation layer before allowing any automated mutation.
- [ ] Refresh/health/status view in Atualizações.
- [ ] Audit trail and disconnect/revoke handling.
- [ ] Keep existing manual/documentary ingestion as fallback.

## P5 — Production readiness / promotion
- [ ] Performance work after correctness/parity, not before.
- [~] Backup/restore surface is canonical and deterministically gated with private versioned export, SHA-256, backend stage/preview, exact confirmation phrase and second browser confirmation; real authenticated export/stage/apply remains pending.
- [~] One automatic traceability receipt now covers the recovered definition of done in one run; infrastructure and deterministic rows pass, while authenticated-real/write and physical-iPhone rows remain OPEN.
- [ ] Real authenticated physical-iPhone material homologation.
- [ ] Real authenticated desktop material homologation as needed.
- [ ] Public `index.html` promotion only after explicit user authorization.
- [x] Preserve fixed homologation/public links.

## Execution order from now
1. Preserve canonical v1.19 product `37781c3b…` and exposure `59222846…` as the current regression baseline.
2. Execute real authenticated desktop and physical-iPhone lifecycles for Dashboard, Flow, search/CSV, classification, liquidity, documents and backup/restore; use them to close the corresponding receipt rows.
3. Keep Bradesco/Cofrinho, card, RSU, CIPÓ and Volvo gaps open until documentary evidence exists; do not infer a closure.
4. Keep the Supabase security baseline regression-protected and review leaked-password protection in a controlled Auth window.
5. Continue Open Finance provider evidence; provider/consent/spend waits for explicit user decision.
6. Promote `index.html` only after the complete receipt and explicit user authorization.

## Current user action
Authenticate the fixed homologation and complete the physical-iPhone material walkthrough; these two gates cannot be executed from the unsigned automated browser. Public-root promotion remains a separate explicit authorization.
