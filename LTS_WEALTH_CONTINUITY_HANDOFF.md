# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-08 08:31 BRT (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial, documentary, classification, reconciliation and product dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, recurrence, reconciliation, valuation, tax or economic-effect rules.
- Ask the user only when a real financial/classification/documentary/provider/consent decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual/data E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence; use normal fast-forward/merge only after fresh compare.
- Preserve historical evidence back to 2013 where supported.

## Fixed links / access
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Public fallback remains WIP35-v136; protected `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.

## Current primary product — canonical v1.9 Flow parity exposure
The primary product line is the single canonical frontend `canonical-app.html`. The v154→v160 wrapper lineage is historical evidence only and must not be reintroduced as the product architecture.

Current facts:
- single frontend; no release iframe/wrapper chain;
- direct Supabase authentication/RPC integration;
- same app owns Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações;
- V157+ modular baseline, v1.8 unified expenses, v1.7 route/session receipt, v1.6 capability recovery, Dashboard Fidelity Pass 6, iPhone future-JWT recovery and the bounded Supabase security baseline remain preserved; current product package is `6aba220653a9053cf304ab11bf931db38ccc1b75`, fixed-manifest exposure `90aad3a754e69708fcc9e03a5bb32835281e2925`;
- Despesas is owned only by `canonical-app`: month/year history, nature × context, evidence-led insights, explicit `Não atribuído` semantics and item/month drilldown are one responsive surface; product module ownership is Patrimônio/Cartões only;
- current changed blobs: `canonical-app.html` `92507f55f4de291c17e49a5b430bedcb33018506`, `canonical-liquidity.js` `8a8caba73c0f6a08710328c19e38bec6c6aab7e9`, `canonical-capabilities-v161.js` `da479e1c5215b593b7bb43d2df5d64dc939e19e2`, permanent gate `f48fc1520f1e50d7071f21be6648a2293fc21e6f`, recovery workflow `9a558c4574eb6439b1eeca0f34400fec2012cdd5`;
- modular recovery gate `34170935882` and permanent canonical gate `34171231918`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844;
- all active/canonical/main candidate smokes and both pre/post-manifest Pages deployments are green; exact run inventory is in the immutable checkpoint;
- Pass 6 recovery/candidate `34185954453` / `34185954506`, canonical gate/candidate `34186087590` / `34186087628`, main candidate/Pages `34186301851` / `34186300869`: SUCCESS;
- post-exposure active/canonical/main smokes `34186663110` / `34186664337` / `34186664887` and Pages `34186664347`: SUCCESS;
- route/receipt recovery/candidate `34190659782` / `34190659780`, canonical gate/candidate `34191017877` / `34191017858`, main candidate/Pages `34191216218` / `34191215874`: SUCCESS;
- post-v1.7-exposure active/canonical/main smokes `34191461669` / `34191462282` / `34191463017` and Pages `34191462402`: SUCCESS;
- fixed homologation exposes canonical v1.9 through `canonical-app.html` / `promotion_status:not_promoted`; public `index.html` remains protected;
- unified-expenses gates are green: active `34199824400`, canonical `34200253901`, main candidate/Pages `34200706521` / `34200704967`;
- canonical v1.9 recovery/candidate `34219446266` / `34219446256`, canonical gate/candidate `34219669569` / `34219669492`, main candidate/Pages `34219911180` / `34219909612`: SUCCESS;
- post-exposure active/canonical/main smokes `34220841617` / `34220895671` / `34220950755` and Pages `34220949477`: SUCCESS;
- live fixed-URL verification resolved to product `6aba220…`, loaded `canonical-liquidity.js?v=20260908-flow-parity9`, used no iframe and rendered truthful login with no unauthenticated fixture values;
- latest immutable checkpoint: `backups/CANONICAL_APP_V19_V150_FLOW_PARITY_CHECKPOINT_2026-09-08.md`;
- authenticated physical-iPhone financial/data E2E remains pending/not claimed.

## Canonical v1.9 Flow interaction recovery — green and selected for fixed homologation
- Git-history audit recovered the exact V150–V160 lineage: V150–V152 kept inline invoice detail, rich semantic movements, projection split and interaction continuity; V153 simplified the visible Flow; V154–V160 focused on visual/data/session recovery without fully restoring those behaviors.
- `canonical-flow-v157.js` now carries contract `v150-validated-flow-plus-v157-liquidity-v1`, preserving `lts_browser_flow_v8`, four account views, ten periods and 14 consolidated liquidity/economic layers.
- Restored canonical interactions: dedicated Hoje, five complete future days, expansion scroll preservation, inline reconciled invoice summary/full detail, semantic transfer/net-salary labels and append-only edit/duplicate/split/cancel with live split sum.
- Permanent gate covers these interactions and Flow-specific mobile overflow. Local Chromium desktop/mobile and CI Chromium/WebKit are PASS; fixed-manifest exposure is in this release package. Authenticated real mutations/invoices and physical iPhone remain explicitly open/not claimed.

## Canonical v1.7 — route/session continuity and one readiness receipt
- `canonical-route-session-continuity-v1` resolves the intended route before the first RPC/render and stores only allowlisted navigation state in `sessionStorage`.
- Refresh, signed-out login, future-JWT reset, direct deep links, browser back/forward and bfcache preserve or safely canonicalize route intent; invalid routes fall back to Dashboard.
- Central de Gestão restores one of eight allowlisted panes after refresh/back without changing the six-route mobile contract.
- The permanent browser gate emits `lts-canonical-definition-of-done-receipt-v1`; artifact `10042106418`, digest `sha256:69ef7f8af36374e9c91ae5074690d13525676d8fe8ee326024c40e381e36ed47`.
- Receipt semantics are binding: `gate_status: PASS` means the deterministic suites passed; `delivery_status: AUTOMATED_GATE_PASS_REAL_E2E_OPEN` means authenticated real-data/write lifecycles, physical iPhone and public-root promotion are still not claimed.

## Canonical v1.6 — recovered briefing capabilities
- Central de Gestão is grouped inside `Atualizações`; desktop receives secondary intent links while mobile keeps exactly six primary destinations.
- Visible inventory: Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.
- Real authenticated readers: `lts_browser_planning_executive_v1`, `lts_browser_recurring_future_gap_audit_v4`, `lts_browser_vesting_scenario_v1`, `lts_browser_backup_status_v1`, `lts_browser_backup_export_v1`, `lts_browser_restore_stage_v1`, `lts_browser_restore_apply_v1`, `lts_browser_open_finance_status_v1`, `lts_browser_wealth_detail_v1`, `lts_browser_document_lifecycle_v1`.
- All ten functions deny `anon` EXECUTE and allow `authenticated` EXECUTE. This is intentional browser-RPC reachability, not proof that every historical SECURITY DEFINER function is safe.
- Recurrence and scenario paths are read-only; planning never projects new FGTS accrual; reconciliation keeps difference R$0; fixture blocks backup/restore writes.
- Real restore is non-destructive/staged: local checksum verification, backend preview, exact phrase, second browser confirmation and apply. Real authenticated backup/restore remains pending/unclaimed.
- Reports expose executive JSON and recurrence CSV; the full financial backup remains separate and explicitly private.

## Durable briefing and validation map
- `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` is the canonical crosswalk for original briefing, Dashboard model lineage, V150/V151 decisions, implementation, automatic proof, user/real-life proof and exact gaps.
- The app-level target remains daily use without Excel, reliable past/today/90-day Flow, integrated cards/recurrences/commitments/transfers/simulations/reconciliation and zero financial divergence.
- The six primary routes may group secondary capabilities, but Financing, Planning, Revenues/Inputs, Recurrences, Commitments, Simulations, Reconciliation, Reports, Documents and Settings must not silently disappear.
- Historical indexed conversation recovery is partial; absence from search never authorizes removing a requirement.

## iPhone future-JWT recovery
- A real iPhone showed raw fatal `JWT issued at future`.
- The shared canonical RPC/session layer now performs bounded clock-skew retry, one coalesced refresh and safe cached-session reset.
- WebKit explicitly gates a persisted future token and the safe return to login without raw JWT exposure.
- Physical authenticated post-fix/data E2E is still pending and remains honestly unclaimed.

## Deterministic canonical evidence
Current gate preserves the prior six-route regression coverage and additionally proves the deterministic Aplicar/Resgatar preview:
- explicit application/redemption control;
- explicit account and documented cash-investment asset;
- positive amount parser including `5 mil`;
- equal-and-opposite bank/asset preview;
- economic effect `R$ 0,00`;
- fixture writer disabled so no financial fact is posted;
- desktop Chromium and mobile WebKit have no horizontal overflow/page error;
- unauthenticated no-fixture state exposes the real login.

This is deterministic fixture/unauthenticated evidence, not authenticated physical-device E2E.

## Official visual / Dashboard target
- Authoritative reference: original 1312×1199 approved image, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.
- Target remains dark desktop rail, light dense executive canvas, compact spacing and intentional mobile layout.
- Liquidity-first hierarchy remains evidence-led.
- Pass 6 closes the major structural differences in navigation breadth, month/as-of controls, top KPI evidence, bank position and working decision drill-downs.
- Pixel-perfect parity, richer evidence-backed historical chart detail and authenticated real-data presentation remain open; the approved image defines presentation/hierarchy, never financial values.

## Current financial/product invariants
### Dashboard / Planning / FGTS
- Bank cash R$15.794,43; D0 R$42.929,50; current vested D+3 R$12.909,65; liquidity through D+3 R$71.633,58.
- `Contas + curto prazo` remains evidence-only arithmetic.
- FGTS exact documentary balance R$22.432,31 at 21/08/2026; restricted / approximately D+30; never D+3.
- No future FGTS deposit/accrual projection.
- Current audited planning: request FGTS by 30/11/2026; management/action point 30/12/2026; first uncovered gap 30/01/2027; worst before FGTS -R$25.782,39; worst after current documentary FGTS -R$3.350,08.
- Historical R$3.700/month FGTS accrual and dependent R$32.309,05 outputs are historical only.
- Future RSUs remain excluded until vest/settlement.

### Natural liquidity input
- Backend browser contract: options → preview → explicit approval/apply → atomic refresh/readback.
- Application and redemption use equal-and-opposite bank↔cash-investment legs and economic effect exactly R$0; they do not become income/expense.
- Browser path supports today/future movements only.
- Idempotency prevents a repeated confirmation from double-applying a movement.
- Canonical Atualizações now exposes this path with explicit account, asset, value and date; no account/asset is guessed.
- Deterministic UI is gated, but real authenticated liquidity save→refresh→visible remains pending because no real financial movement was posted during testing.

### RSU / Organon
- Current documentary position 03/09/2026: 184,483 shares / R$12.909,65 / D+3.
- Previous 18/08/2026 snapshot: 459,483 shares / R$32.772,30; historical only.
- Current metadata records a 275-share reduction after the prior snapshot and a user-confirmed sale, but exact trade settlement date/price/proceeds remain pending documentary reconciliation.
- Brokerage cash R$2.862,67 is separately `available_unclassified` and excluded from D0/D3 until transfer latency is evidenced.
- Do not invent quantity/gross/fees/FX for historical proceeds where evidence is incomplete.

### Despesas
- Economic invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature and context/person/cost center distinct.
- Canonical route consumes `lts_browser_expense_context_lens_v1` and keeps read-only drilldowns/historical periods.
- Classification hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- Marketplace/intermediary alone never proves purchase purpose.
- Continue decision-useful density/ranking and evidence-only reduction of `A classificar`.

### Atualizações / search / documents / classification
- Compact prioritized action center; no large blank whitespace or buried actions.
- `Lançamento por texto` remains preview/review first; no automatic posting.
- Server-side incremental search uses `lts_browser_transactions_v1`, includes total and Excel-compatible CSV; deterministic UI gate passed.
- Mastercard backend evidence: 239 rows spanning 01/11/2013–12/04/2028.
- Classification writer `lts_browser_semantic_feedback_v1`; canonical lifecycle wiring performs save → product refresh/read verification.
- Document lifecycle reader `lts_browser_document_lifecycle_v1` is surfaced in canonical Atualizações.
- Real authenticated classification, transaction-search and PDF/image interpret→review E2E remain pending/unclaimed.

### Fluxo Diário / mutation semantics
- Mandatory Consolidado, Itaú, Bradesco, C6.
- Facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- Bank↔liquidity-asset transfer consolidated economic effect zero.
- Append-only edit/cancel/split semantics proven: current-event overlays append to `lts_flow_event_operation`; legacy overrides append to `projecao_op`; mutations append to `lts_flow_mutation_audit`; source facts are not destructively rewritten.
- `lts_fix86_legacy_guardrails_qa_v4` passes 10/10 including `flow_mutations_append_only_operational`.
- Separate user-facing undo/reversal is not claimed/enabled without an explicit append-only reversal contract.

### Cartões
- Certified allocation 38 cycles / 650 rows / R$885.855,19.
- Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 explicit R$66,70 gap remains.
- Mastercard/Visa incomplete historical months remain documentary recovery only; never pattern-fill purchases.

### CIPÓ 396
- Distinct consortium entries R$6.654,50 on 12/05/2023 and R$151,80 on 15/05/2023; never present as same-date arithmetic.
- R$303,60 consortium delta unresolved; Visa Infinite R$303,60 rows are not consortium evidence.
- Condominium source/formula/cutoff absent.
- Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70 unresolved.
- Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.

### Volvo
- Bradesco financing 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically.
- Exact trim/version and km remain required before valuation refinement.

### Open Finance
- Provider-neutral architecture QA 14/14.
- `lts_browser_open_finance_status_v1` exposes architecture/connections/sync health; provider records are staged/reconciled before canonical financial effect; no bank credentials/provider secrets are stored in LTS tables under the current contract.
- No provider selected/activated by project decision; no consent/token/commercial commitment claimed.
- Need written pricing/support/SLA, exact product×bank coverage for Itaú/Bradesco/C6, scope, history depth, refresh/webhooks, consent renewal, errors and sandbox quality.
- Provider/spend/consent remains a future user decision.

### Supabase security hardening
- Migration `20260908045049 canonical_security_rls_and_flow_helper_acl_2026_09_08` is applied. The 13 audited tables now have RLS and no direct `PUBLIC`/`anon`/`authenticated` DML grants.
- The audit found 12 internal SECURITY DEFINER Flow/cache helpers that accepted explicit arbitrary `user_id` and inherited client EXECUTE through postgres defaults. They are now internal-only. Browser Flow wrappers v7-v10 remain authenticated-only and derive the user through `lts_browser_assert_user_v1`.
- Postflight returned 13/13 RLS, 12/12 helpers closed, 4/4 wrappers authenticated-only, zero anonymous SECURITY DEFINER execution and zero authenticated SECURITY DEFINER functions without a direct allowlist/JWT/user guard. Default client grants are zero; `service_role` remains preserved.
- Authenticated transactional regression passed for Flow v8, Dashboard cockpit and product contract, then rolled back. Advisor no longer reports RLS-disabled or anonymous SECURITY DEFINER findings. No-policy INFO notices on the 13 internal tables are intentional deny-by-default behavior.
- Leaked-password protection remains disabled and must be handled as a separate controlled Auth-setting change.

## Historical release lineage retained, not current
- v154 accepted visual direction; v155 false-zero/navigation correction; v156 liquidity-first but rejected real iPhone; v157 WebKit deterministic pass but real-device rejection; v158 truthful fallback/product regression; v159 presentation restored but KPI data unavailable on real iPhone; v160 material-data readiness/truthful fallback; canonical app supersedes all as primary architecture.

## Open backlog that must always remain visible
- Evidence-led Dashboard detail convergence beyond the protected Pass 6 baseline; pixel-perfect parity is not claimed.
- Close the unified receipt rows that require authenticated real-data/write lifecycles and physical-device evidence; do not reinterpret automatic PASS as final delivery.
- Controlled Auth review/enablement of leaked-password protection; database RLS/SECURITY DEFINER hardening is closed and must remain regression-protected.
- Authenticated physical-iPhone canonical financial/data E2E.
- Real authenticated liquidity save→refresh→visible.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation→review.
- Real authenticated server-side search/CSV E2E.
- User-facing undo/reversal only after explicit append-only reversal contract; cancel/edit/split already proven append-only.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery.
- Current/historical RSU sale documentary detail where not evidenced.
- CIPÓ R$303,60 delta, condominium source, raw/dedup gaps, duplicate excess.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank comparison; no provider/consent/spend without explicit authorization.
- Audit all dependencies/improvements back to 07/07/2026.
- Public promotion only after explicit user approval.
- Preserve official-reference visual language, mobile/desktop usability, backup/restore and traceability.

## User action now
NONE. Continue autonomous Dashboard/product-quality work. User may test the fixed homologation when a material candidate is published, but engineering work must not wait for that QA.

## Route/session continuity + unified receipt — 08/09/2026
- Route and management-pane intent now survive refresh/session restoration/back-forward under explicit allowlists; the future-JWT safe reset returns to login without discarding the intended product route.
- The permanent recovery/canonical gates cover Chromium desktop 1312×1199 and WebKit mobile 390×844, including direct links, invalid-route fallback, bfcache/back-forward, selected management pane and route preservation through JWT recovery.
- Product target `e618ef48e22872ce718c7932872e2316e5660f67`; exposure `33da29ab0818c9dd59dca45f68d3680ed153f6af`; all pre/post-exposure smokes and Pages are green.
- The generated receipt is the single automatic evidence index, not a claim of authenticated physical-device completion. Public `index.html` remains unchanged.

## Dashboard Fidelity Pass 6 — 08/09/2026
- Approved-reference desktop intent order, month/as-of controls, working `Hoje` reload, five evidence labels, bank rows and real route drill-downs are implemented without changing the liquidity-first financial contract.
- Mobile preserves exactly six primary destinations and exposes the period controls without clipping; Central de Gestão keeps all ten recovered briefing capabilities.
- The canonical gate found and blocked a mobile scenario race caused by redundant delayed remounts; the product now preserves form state and both browser gates are green after the fix.
- Product target `9ae0ee37ab3332415523eeee287cdbf75102e1c4`; homologation exposure `4d3c7bc912a672ae7353c7028d8b05d047961dd5`; all pre/post-exposure smokes and Pages are green.
- Active artifact `10040515495`, digest `sha256:e8b4403df49125b5251f751378e4e84f7c9704abac55c40d8324e05a895009a2`; canonical artifact `10040555899`, digest `sha256:e3d4685de0887ce0711f42fd16adcbecd33ef0311466749383b4d0c45bca7883`.
- Browser verification of the fixed URL showed Pass 6 assets, clean login, no unauthenticated financial KPI and no iframe. Authenticated physical-iPhone financial/data E2E and pixel-perfect parity remain unclaimed.


## Latest product-recovery exposure — 07/09/2026
- Split V157+ module architecture is now covered by both the recovery and permanent canonical gates.
- Product/gate source `76f888dc0e668fb0e768c8cc825f56778f043f50`; homologation target `c44d401497e14d842d433a302006ff5648b956a9`; manifest exposure `3b3048fa4660868e161582fcd8704438a13e300c`.
- Recovery `34170935882`, permanent canonical `34171231918`, all active/canonical/main candidate smokes and Pages deployments: SUCCESS.
- Historical v144–v160 workflows retain branch/manual execution but no longer auto-trigger on `main`.
- Fixed homologation was directly verified; Dashboard parity remains P0 and pixel-perfect parity is not claimed.
- Real authenticated liquidity save→refresh→visible and authenticated physical-iPhone E2E remain pending/unclaimed.
- `index.html` remains protected/not promoted.

## Dashboard Fidelity Pass 5 — 07/09/2026
- At Pass 5, `canonical-product-v157.js` stopped replacing Dashboard. Canonical v1.8 supersedes its Despesas ownership too; the module now remains responsible only for Patrimônio and Cartões enrichment.
- Canonical Dashboard now keeps the five liquidity-first KPI contract inside the denser approved-reference hierarchy.
- Product source `6eca5c3785cd5dca69a2aa8f610312eefbb2a669`; exact gated target `eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d`; exposure `a808d855aa6687a893a51598db8f5fad4faf1cbb`.
- Recovery gate `34173223977`, permanent canonical gate `34173482173`, final active/canonical/main smokes and Pages: SUCCESS; all post-exposure smokes and Pages are also green.
- Fixed homologation was directly verified at the exact target with Pass 5 asset and truthful unauthenticated login.
- Dashboard pixel-perfect parity and authenticated physical-iPhone financial/data E2E remain explicitly unclaimed.
