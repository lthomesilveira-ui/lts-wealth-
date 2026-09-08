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

## Current execution state — 08/09/2026 01:56 BRT
- Repo: `lthomesilveira-ui/lts-wealth-`; active recovery branch remains `canonical-v157plus-product-recovery`.
- `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` are aligned at Dashboard Fidelity Pass 6 exposure `4d3c7bc912a672ae7353c7028d8b05d047961dd5`.
- Exact product target: `9ae0ee37ab3332415523eeee287cdbf75102e1c4`; canonical v1.6 capability recovery and iPhone future-JWT recovery remain preserved underneath it.
- Pass 6 now matches the approved Dashboard structure materially: exact desktop intent order, month/as-of toolbar, working `Hoje` reload, five evidence-labelled liquidity KPIs, bank rows and decision-card drill-downs. Mobile keeps six primary destinations and exposes the period controls without clipping.
- A deterministic gate exposed a delayed-remount race that could erase a selected vesting scenario on mobile. `canonical-capabilities-v161.js` now preserves form state by avoiding redundant panel replacement; both recovery and canonical gates passed after the fix.
- `canonical-capabilities-v161.js` adds one coherent Central de Gestão inside `Atualizações`, without adding a seventh mobile route. It exposes Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.
- Real authenticated readers are wired for planning, recurring audit, read-only vesting scenario, backup status/export, staged restore, Open Finance status, wealth detail and document lifecycle. Scenario and recurring analysis do not write facts; restore keeps checksum, preview, exact phrase and second confirmation.
- Pass 6 recovery/candidate `34185954453` / `34185954506`, canonical gate/candidate `34186087590` / `34186087628`, main candidate/Pages `34186301851` / `34186300869`: **SUCCESS**.
- Post-exposure active/canonical/main smokes `34186663110` / `34186664337` / `34186664887` and Pages `34186664347`: **SUCCESS**.
- Fixed homologation resolves to `canonical-app.html?homologacao=9ae0ee37ab3332415523eeee287cdbf75102e1c4`; direct verification observed `canonical-dashboard-fidelity.css?v=20260908-pass6`, `canonical-liquidity.js?v=20260908-fidelity6`, truthful login, zero unauthenticated KPI cards and no iframe.
- Supabase hardening migration `20260908045049 canonical_security_rls_and_flow_helper_acl_2026_09_08` is applied. All 13 audited tables now have RLS and no direct client DML grants; 12 arbitrary-user internal Flow/cache helpers are no longer executable by `PUBLIC`, `anon` or `authenticated`; browser Flow v7-v10 remain `authenticated`-only behind `lts_browser_assert_user_v1`.
- Catalog postflight returned 13/13 RLS, 12/12 helpers closed, 4/4 browser wrappers authenticated-only, zero anonymous executable `SECURITY DEFINER` functions and zero authenticated executable `SECURITY DEFINER` functions lacking a direct allowlist/JWT/user guard. Secure defaults now leave zero client default grants while preserving `service_role`.
- Transactional authenticated regression passed for `lts_browser_flow_v8`, `lts_browser_dashboard_cockpit_v1` and `lts_browser_product_v1`, with rollback. Security Advisor no longer reports RLS-disabled or anonymous SECURITY DEFINER findings; leaked-password protection remains the controlled Auth-setting gap.
- Durable briefing, Dashboard lineage, V150/V151 decisions and validation classes remain consolidated in `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md`.
- Latest immutable evidence: `backups/CANONICAL_SUPABASE_RLS_SECURITY_DEFINER_HARDENING_CHECKPOINT_2026-09-08.md`.
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
1. Keep `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` aligned by normal no-force updates only.
2. Use `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` as the durable map from briefing → implementation → validation → pending; append recovered facts rather than relying on chat memory.
3. Treat Dashboard Fidelity Pass 6 as the current protected baseline; continue only evidence-led pixel/detail convergence, never copy financial values from the reference.
4. Treat the bounded Supabase RLS/SECURITY DEFINER package as the protected security baseline; leaked-password protection remains a separate controlled Auth-setting change.
5. Complete refresh/session route restoration, the unified definition-of-done receipt and remaining Despesas/Atualizações product quality without reintroducing wrapper architecture.
6. Keep authenticated physical-iPhone and real write/search/document/backup-restore E2Es explicitly unclaimed until actually performed.
7. Preserve `promotion_status:not_promoted` and protected `index.html` until explicit user authorization.

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
- Flow: Consolidado/Itaú/Bradesco/C6, historical coverage where evidenced, operational balance + liquidity layers, expandable movements, internal transfers neutral in consolidated economics.
- Original source files remain unchanged; no re-entry; historical/reconciliation difference tolerance remains R$0.00.
- Daily balance chain, Realized versus Projected separation, Review for ambiguity, append-only ledger, idempotent ingestion and human approval remain binding domain rules.
- No invented amount, merchant, classification, recurrence, competence, valuation, tax or documentary fact.
- FGTS remains restricted/D+30 context, never automatic current cash.
- Public fallback remains protected until explicit authorization.

## One-line new-chat bootstrap for the user
`Continue LTS Wealth. Leia LTS_WEALTH_EXECUTION_STATE.md no GitHub e continue autonomamente do estado real, sem reconstruir contexto do chat.`

That one line is sufficient. The assistant must recover everything else from GitHub and continue execution.
