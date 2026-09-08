# LTS Wealth — Execution State

Purpose: compact operational bootstrap so project execution never depends on a long ChatGPT conversation. This file is intentionally short and must be updated after every material package/gate/integration.

## Restart-safe operating protocol
1. Read this file first in every new chat.
2. Fetch only branch refs and file SHAs/targeted line ranges for freshness. Do **not** re-load entire long project documents unless their SHA changed or the current task needs a specific section.
3. GitHub remains the operational source of truth. Chat history is not required for continuity.
4. Immutable checkpoints remain evidence archives; do not replay them into chat unless needed for a concrete decision or regression audit.
5. Never echo tool logs, giant diffs, workflow payloads or historical context to the user. User updates stay concise under exactly: `Concluído / Em execução / Próximos passos`.
6. No intermediate QA delegation to the user. Execute deterministic QA first; ask only for real financial/classification/documentary/provider decisions or final material homologation.
7. Before a repository write, freshness-check `main`, active branch, this file, and the SHAs of `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `CANONICAL_DELIVERY_MASTER_PLAN.md` and latest immutable checkpoint. Use line-limited reads; fully re-read only a file whose SHA changed or whose relevant section is needed.
8. After every material package, gate, integration or newly discovered blocker, update this file so a chat may be abandoned/restarted at any moment without reconstruction work.

## Current execution state — 08/09/2026 11:16 BRT
- Repo: `lthomesilveira-ui/lts-wealth-`; active recovery branch remains `canonical-v157plus-product-recovery`.
- Canonical v1.12 exact product is `70c49b1b50b7faca09b71889e14d33183a7f9092`; fixed-manifest exposure is `adac528dbde6d0dcd6268a52c780d3abf43dc9a9`. All three branches share both commits through normal fast-forward. Public `index.html` remains untouched.
- V150→canonical audit found a real omission: V150 exposed `Lançamento por texto`, but canonical v1.11 rendered no equivalent surface despite the documented requirement. V1.12 restores it in `Atualizações` under `review-before-explicit-apply-v1` without restoring wrapper architecture.
- Preview parses the five required BRL forms, relative/explicit date, known account/card and evidence-limited nature/category/context proposals. Every field remains editable; no write occurs before checked review plus explicit confirmation; fixture mode has no apply action and never invokes `lts_browser_apply_reviewed_input_v1`.
- V1.12 preserves v1.11 layered liquidity, v1.10 decision truth, v1.9 V150/V151+ Flow parity, v1.8 single-owner Despesas, route/session continuity and the Supabase security baseline.
- Pre-exposure recovery gate/smoke `34235638676` / `34235638646`, canonical gate/smoke `34235911409` / `34235911280`, main smoke/Pages `34236205811` / `34236204118`: SUCCESS. Post-exposure active/canonical/main smokes `34236480960` / `34236541857` / `34236635343` and Pages `34236635451`: SUCCESS.
- Recovery artifact `10059792070`, digest `sha256:db41ecbe329e9166c60241a4461fd33ef963aedd3a7953ac072356cbcc0e3eae`; canonical artifact `10059891042`, digest `sha256:a84c36b967cba64d524241a19a476d7a9747386046b7bb86799f4b8a328e34eb`.
- Fixed URL was browser-verified at `canonical-app.html?homologacao=70c49b1…#Dashboard`, loading `canonical-liquidity.js?v=20260908-input12`, truthful signed-out login, zero iframes and no unauthenticated fixture Dashboard. Authenticated real save/readback and physical-iPhone evidence remain open and are not claimed.
- V1.11 remains the protected predecessor for layered liquidity; V1.10 remains the predecessor for fact/projection and commitment/task separation; v1.9 remains the protected Flow interaction floor.
- Canonical v1.9 exposed baseline restores the validated V150 Flow interactions on top of the later canonical liquidity model under contract `v150-validated-flow-plus-v157-liquidity-v1`: inline card-invoice detail, append-only edit/duplicate/split, semantic movement labels, net salary evidence, internal-transfer direction, dedicated `Hoje`, five complete future days and scroll preservation.
- The V150→V160 audit established the exact loss point: V150–V152 retained the rich protected Flow; V153 replaced it with a reduced native five-column surface; V154–V160 fixed presentation/data/session concerns without restoring all those interactions. The wrapper architecture remains retired; only validated behavior was ported into the single canonical frontend.
- The permanent gate exercises the restored Flow in addition to the six-route product: 14 consolidated layers, four account views, five-day horizon, inline invoice summary/full detail, semantic transfer/salary labels, split add/remove/sum, fixture write boundary and mobile Flow overflow. Local Chromium desktop/mobile and CI Chromium desktop/WebKit 390×844 are PASS.
- Canonical v1.9 pre-exposure evidence is green: active recovery gate/smoke `34219446266` / `34219446256`, canonical gate/smoke `34219669569` / `34219669492`, main smoke/Pages `34219911180` / `34219909612`. Recovery artifact `10053154126`, digest `sha256:711c1d2d19d558d9caf6d0cd40bdddc47416b344353851ed8884344e7d355a17`; canonical artifact `10053239237`, digest `sha256:fdc1d83505d2ccd1cf8529aec088518e42e344115c24c7c13eb3f789f01e6a0f`.
- Post-exposure active/canonical/main smokes `34220841617` / `34220895671` / `34220950755` and Pages `34220949477`: SUCCESS.
- Live fixed-URL verification resolved to `canonical-app.html?homologacao=6aba220…`, loaded `canonical-liquidity.js?v=20260908-flow-parity9`, rendered the truthful signed-out login, used zero iframes and exposed no fixture financial content. Authenticated data/write behavior and a physical iPhone remain separate, explicitly open evidence.
- Exact exposed product package: `6aba220653a9053cf304ab11bf931db38ccc1b75`; v1.8 source `870acc37f220592c77b488be32315af284b52427`, Dashboard Fidelity Pass 6, canonical v1.7 route/session receipt, canonical v1.6 capability recovery, iPhone future-JWT recovery and the bounded Supabase security baseline remain preserved underneath it.
- Despesas now has one DOM owner (`canonical-app`): month/year history, nature × context, evidence-led insights, `Não atribuído` semantics and item/month drilldown coexist in one gated responsive route. `canonical-product-v157.js` is limited to Patrimônio and Cartões.
- Unified-expenses active gate/candidate `34199824400` / `34199824442`, canonical gate/candidate `34200253901` / `34200253918`, post-manifest active/canonical smokes `34200631320` / `34200627680`, main candidate/Pages `34200706521` / `34200704967`: **SUCCESS**.
- Unified-expenses artifact `10045384567`, digest `sha256:d2217881f768ee07bd28c846026447571fa89b932a9af944fccfed8bba4523382`.
- The canonical router now derives the intended route before the first RPC/render, canonicalizes deep links, persists only route state in `sessionStorage`, preserves intent through login/JWT reset/reload, handles `popstate`/bfcache and falls back safely from invalid routes. Central de Gestão also restores one of its eight valid panes across refresh/back.
- The permanent browser gate now emits one `lts-canonical-definition-of-done-receipt-v1` JSON receipt. It maps the recovered requirements and explicitly separates `gate_status: PASS` from `delivery_status: AUTOMATED_GATE_PASS_REAL_E2E_OPEN`; authenticated real data/writes, physical iPhone and public-root promotion remain unclaimed.
- Pass 6 now matches the approved Dashboard structure materially: exact desktop intent order, month/as-of toolbar, working `Hoje` reload, five evidence-labelled liquidity KPIs, bank rows and decision-card drill-downs. Mobile keeps six primary destinations and exposes the period controls without clipping.
- A deterministic gate exposed a delayed-remount race that could erase a selected vesting scenario on mobile. `canonical-capabilities-v161.js` now preserves form state by avoiding redundant panel replacement; both recovery and canonical gates passed after the fix.
- `canonical-capabilities-v161.js` adds one coherent Central de Gestão inside `Atualizações`, without adding a seventh mobile route. It exposes Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.
- Real authenticated readers are wired for planning, recurring audit, read-only vesting scenario, backup status/export, staged restore, Open Finance status, wealth detail and document lifecycle. Scenario and recurring analysis do not write facts; restore keeps checksum, preview, exact phrase and second confirmation.
- Pass 6 recovery/candidate `34185954453` / `34185954506`, canonical gate/candidate `34186087590` / `34186087628`, main candidate/Pages `34186301851` / `34186300869`: **SUCCESS**.
- Post-exposure active/canonical/main smokes `34186663110` / `34186664337` / `34186664887` and Pages `34186664347`: **SUCCESS**.
- Route/receipt recovery/candidate `34190659782` / `34190659780`, canonical gate/candidate `34191017877` / `34191017858`, main candidate/Pages `34191216218` / `34191215874`: **SUCCESS**.
- Route/receipt artifact `10042106418`, digest `sha256:69ef7f8af36374e9c91ae5074690d13525676d8fe8ee326024c40e381e36ed47`; desktop Chromium and mobile WebKit suites are PASS, including refresh, back/forward, direct deep link, invalid-route fallback, management-pane restore and future-JWT route preservation.
- Post-exposure active/canonical/main smokes `34191461669` / `34191462282` / `34191463017` and Pages `34191462402`: **SUCCESS**.
- Fixed homologation exposes canonical v1.9 through `canonical-app.html`; direct verification observed `canonical-liquidity.js?v=20260908-flow-parity9`, the unified expense and V150 Flow-parity contracts, and no iframe. Clean-session/authenticated-real claims remain bounded by their separate gates.
- Supabase hardening migration `20260908045049 canonical_security_rls_and_flow_helper_acl_2026_09_08` is applied. All 13 audited tables now have RLS and no direct client DML grants; 12 arbitrary-user internal Flow/cache helpers are no longer executable by `PUBLIC`, `anon` or `authenticated`; browser Flow v7-v10 remain `authenticated`-only behind `lts_browser_assert_user_v1`.
- Catalog postflight returned 13/13 RLS, 12/12 helpers closed, 4/4 browser wrappers authenticated-only, zero anonymous executable `SECURITY DEFINER` functions and zero authenticated executable `SECURITY DEFINER` functions lacking a direct allowlist/JWT/user guard. Secure defaults now leave zero client default grants while preserving `service_role`.
- Transactional authenticated regression passed for `lts_browser_flow_v8`, `lts_browser_dashboard_cockpit_v1` and `lts_browser_product_v1`, with rollback. Security Advisor no longer reports RLS-disabled or anonymous SECURITY DEFINER findings; leaked-password protection remains the controlled Auth-setting gap.
- Durable briefing, Dashboard lineage, V150/V151 decisions and validation classes remain consolidated in `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md`.
- Latest immutable evidence: `backups/CANONICAL_APP_V112_REVIEWED_TEXT_INPUT_CHECKPOINT_2026-09-08.md`.
- Authenticated physical-iPhone post-fix financial/data E2E and authenticated real backup/restore/write lifecycles are still **not claimed**.
- Public `index.html` remains protected at blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; public-root promotion is not authorized.

## Prior Dashboard Pass 5 state — retained as evidence
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Exposed product baseline shared by `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery`: `a808d855aa6687a893a51598db8f5fad4faf1cbb` — Dashboard Fidelity Pass 5 exposed through the fixed homologation manifest; public root still protected.
- Active recovery branch: `canonical-v157plus-product-recovery`.
- V157+ recovery implementation: `76f888dc0e668fb0e768c8cc825f56778f043f50`; Dashboard owner/fidelity implementation: `6eca5c3785cd5dca69a2aa8f610312eefbb2a669`; exact green manifest target: `eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d`; exposure manifest commit: `a808d855aa6687a893a51598db8f5fad4faf1cbb`.
- V157+ recovery gate run `34160992326`: **SUCCESS**.
- V157+ presentation-polish gate run `34161414516`: **SUCCESS**.
- V157+ modular recovery gate run `34170935882`: **SUCCESS** in desktop Chromium 1312×1199 and mobile WebKit 390×844.
- Active candidate smoke `34170935887`, permanent canonical gate `34171231918`, canonical candidate smoke `34171231935`, main candidate smoke `34171338575` and Pages `34171338335`: **SUCCESS**.
- Post-manifest candidate smokes on active `34171452083`, canonical `34171452913`, main `34171453488`, and Pages `34171452759`: **SUCCESS**.
- Dashboard Pass 5 recovery gate `34173223977`, final active candidate smoke `34173481335`, permanent canonical gate `34173482173`, canonical candidate smoke `34173482194`, main candidate smoke `34173586238` and Pages `34173586282`: **SUCCESS**.
- Pass 5 exposure smokes active `34173674961`, canonical `34173674230`, main `34173673390`, and Pages `34173673353`: **SUCCESS**.
- Permanent canonical gate now validates the split `canonical-liquidity-core.js`, `canonical-flow-v157.js`, `canonical-product-v157.js` and `canonical-presentation-v157.js` architecture while retaining prior classification, search/CSV, document and neutral liquidity-movement contracts.
- Recovery covers the richer Flow contract, executive Despesas/Patrimônio/Cartões surfaces, mobile Flow layers, visible build identification and the canonical single-frontend architecture.
- Current Flow recovery uses backend `lts_browser_flow_v8`; deterministic gate is green. Authenticated physical-iPhone financial/data E2E is still **not claimed**.
- Dashboard now remains owned by the dense canonical app instead of being replaced after load by the simplified V157+ module. Its five liquidity-first KPIs and reference-level section hierarchy are gated; further pixel-level convergence remains P0.
- Public `index.html` remains protected; public-root promotion is not authorized.
- Fixed homologation `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` resolves to `canonical-app.html?homologacao=eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d`; live verification showed the Pass 5 canonical script and truthful unauthenticated login, not fixture financial content.
- Historical v144–v160 workflows remain manually/branch runnable but no longer run automatically on `main`; their wrapper-specific failures are not canonical release gates.

## Current immediate execution sequence
1. Treat canonical v1.12 product `70c49b1…` and exposure `adac528…` as the current protected baseline; do not regress its reviewed-input contract, v1.11 layered liquidity, v1.10 decision truth, v1.9 V150 Flow or public `index.html`.
2. Use `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` as the durable map from briefing → implementation → validation → pending; append recovered facts rather than relying on chat memory.
3. Continue the audit of both historical projects and evidence-led product detail without copying financial values from reference images; recovered feedback is binding only where explicitly attributed to the user.
4. Treat the bounded Supabase RLS/SECURITY DEFINER package as the protected security baseline; leaked-password protection remains a separate controlled Auth-setting change.
5. Keep the route/session continuity contract and unified receipt regression-protected; the automatic gate is complete, while its authenticated-real/physical-device rows remain honestly open.
6. Keep the v1.8 single-owner Despesas route, v1.9 V150 Flow parity, v1.10 fact/projection/commitment semantics, v1.11 liquidity layers and v1.12 reviewed input regression-protected; continue remaining product quality and execute real write/search/document/backup-restore lifecycles when an authenticated browser identity is available.
7. Keep authenticated physical-iPhone E2E explicitly unclaimed until actually performed.
8. Preserve `promotion_status:not_promoted` and protected `index.html` until explicit user authorization.

## Previous immediate sequence — superseded by the sequence above
1. Keep `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` aligned by normal no-force updates only.
2. Continue Dashboard fidelity P0 against the approved 1312×1199 reference using real data only.
3. Continue remaining report/updates product recovery without reintroducing wrapper architecture.
4. Keep authenticated physical-iPhone financial/data E2E explicitly unclaimed until it is actually performed.
5. Preserve `promotion_status:not_promoted` and protected `index.html` until explicit user authorization.

## Product invariants not to lose
- One canonical frontend; no iframe/wrapper chain as primary architecture.
- Six real routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Financing, Planning, Revenues/Inputs, Recurrences, Commitments, Simulations, Reconciliation, Reports, Documents and Settings remain required capabilities even when grouped under the six primary routes; do not silently delete them.
- Daily-use target is replacement of the Excel, with reliable past/today/90-day Flow and automatic release receipts; that target is not complete until the real authenticated gates are closed.
- Flow: Consolidado/Itaú/Bradesco/C6, historical coverage where evidenced, operational balance + 14 consolidated liquidity layers, expandable movements, inline reconciled card detail, semantic labels, dedicated Hoje/five-day horizon, append-only edit/duplicate/split and internal transfers neutral in consolidated economics.
- Original source files remain unchanged; no re-entry; historical/reconciliation difference tolerance remains R$0.00.
- Daily balance chain, Realized versus Projected separation, Review for ambiguity, append-only ledger, idempotent ingestion and human approval remain binding domain rules.
- No invented amount, merchant, classification, recurrence, competence, valuation, tax or documentary fact.
- FGTS remains restricted/D+30 context, never automatic current cash.
- Public fallback remains protected until explicit authorization.

## One-line new-chat bootstrap for the user
`Continue LTS Wealth. Leia LTS_WEALTH_EXECUTION_STATE.md no GitHub e continue autonomamente do estado real, sem reconstruir contexto do chat.`

That one line is sufficient. The assistant must recover everything else from GitHub and continue execution.
