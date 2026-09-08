# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Never remove an open financial, documentary, classification, reconciliation or product dependency during compaction. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and release checkpoints.

## P0 — Approved Dashboard desktop density / canonical v1.15 — 08/09/2026
- [x] Compared the canonical Dashboard against the official 1312×1199 reference and isolated a measurable 126 px desktop overflow: canonical v1.14 document height was 1325 px.
- [x] Added contract `approved-1312x1199-single-screen-v1` without changing financial values, observed/projected semantics, commitments, routes or mobile ownership.
- [x] Reduced only desktop chart/legend footprint: main liquidity panel 350→295 px and planning panel 373→297 px; page now equals 1199 px and Dashboard bottom is 1184 px.
- [x] Kept both four-layer legends on one readable line: current position, operating base, scheduled vestings and documentary FGTS D+30.
- [x] Mobile remains intentionally scrollable at 390×844 with all cards/targets and no horizontal clipping.
- [x] Permanent gate rejects desktop document/Dashboard overflow, panel height >315 px or missing legend layer while preserving every v1.14→v1.9 suite and future-JWT recovery.
- [x] Local permanent Chromium gate, JS/YAML parsing and `git diff --check`: PASS; `index.html` protected hash unchanged.
- [x] Exact remote product `a0a2675e6a9c9b3ffe4d9b0bc1fab222a48bc347`, tree `667ef2fcae8c5630b5a60b4d62ee2986ad438e92`; exposure `b1998a9178ef3a8eec90dd47aa21e31dad8c868a`, tree `f8a68fa98658f1718eccfd6b716f4607ad2d516e`; all three branches aligned by normal no-force fast-forward.
- [x] Product recovery gate/smoke `34256124696` / `34256124706`, canonical gate/smoke `34256598442` / `34256598444`, main smoke/Pages `34256889054` / `34256887644`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34257179939` / `34257183053` / `34257139985` and Pages `34257139795`: SUCCESS; fixed URL loads exact v1.15 assets with truthful blank signed-out login, zero iframe/fixture/JWT leakage.
- [x] Artifacts: recovery `10067974348` / `sha256:302bccf618422a2d0a2ade4fd696441a71f8c490707be3aa54f75afce974412d`; canonical `10068181842` / `sha256:1b2c2310394b6d834d88ba015d596648e88ae517489b54f40e89c7c17e6380d5`; exposure Pages `10068319425` / `sha256:9820c15422ab8226db2edd51490ba328b08d933a6c1b07f05a50f3614db1f228`.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V115_DASHBOARD_DENSITY_CHECKPOINT_2026-09-08.md`.
- [ ] Authenticated real-data Dashboard and physical-iPhone evidence remain open/not claimed; remaining visual refinements require recovered/approved evidence and must preserve this density floor.

## P0 — V149 document interpretation review recovery / canonical v1.14 — 08/09/2026
- [x] Recovered the V149 read-only review that contrasted the association supplied by the user with evidence extracted from the document; the capability had disappeared from the later canonical surface.
- [x] Added contract `v149-evidence-review-readonly-canonical-v1` without restoring wrapper architecture or changing the V147 classification-first priority.
- [x] Each card shows `Vínculo informado por você`, `Leitura extraída do arquivo`, bounded escaped evidence, missing-link warning and an explicit `Somente leitura` barrier.
- [x] The review has zero buttons/inputs and cannot approve, reconcile, classify, overwrite association or post financial facts; fixture proof requires `write_allowed:false` and `financial_writer_called:false`.
- [x] Added guarded browser RPC `lts_browser_document_review_queue_v1` plus owner-scoped bounded internal reader `lts_document_review_queue_v1`; migration `canonical_document_review_read_model_2026_09_08` applied.
- [x] Verified privileges and failure boundaries: wrapper authenticated/service-role only behind `lts_browser_assert_user_v1`; internal reader service-role only; zero-UUID response safe; unauthenticated call fails `42501 unauthorized`.
- [x] Local permanent gate PASS at 1312×1199 and 390×844; two fixtures, 12+ evidence rows, exact contract, zero controls/writers, no overflow; button audit remains 197/197 and `index.html` hash is unchanged.
- [x] Exact remote product `0d50699af5aa5b950ff889a1fc6becfee209ce06`, tree `f086c6878f4737a10c6865768241e9d2c4adc326`; exposure `ac5d4674920615c6c5e5947d4ab721f538679a0c`, tree `e4d9796e6646a2265ca62c5de4b7058ac6b487cb`; all three branches aligned by normal no-force fast-forward.
- [x] Product recovery gate/smoke `34250450654` / `34250450670`, canonical gate/smoke `34250649137` / `34250649010`, main smoke/Pages `34250977997` / `34250976391`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34251224292` / `34251281745` / `34251333462` and Pages `34251332488`: SUCCESS; fixed URL loads exact v1.14 assets with truthful signed-out state, zero iframe/fixture/JWT leakage.
- [x] Artifacts: recovery `10065805910` / `sha256:50a3687a1ff0d86dc74c0c8a7d2be6066b0b47a5634f1f392692237de30322c7`; canonical `10065921441` / `sha256:7a292b5f5ce280ebac2f57ae53520d45bf37fcaa2d145a6351100e0f2f2a4a18`; exposure Pages `10066100348` / `sha256:8d3f15e7be00a045f48066859f833bf2b79df7a23eac652742090056ae6fb36e`.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V114_DOCUMENT_INTERPRETATION_REVIEW_CHECKPOINT_2026-09-08.md`.
- [ ] Real authenticated upload→register→interpretation→review/readback and physical-iPhone evidence remain open/not claimed; no approval or financial writer is part of this surface.

## P0 — Classification-first Updates + guided document intake / canonical v1.13 — 08/09/2026
- [x] Recovered the binding V147 hierarchy: classification is foreground; `Outras ações que precisam de você` is collapsed and owns documents plus secondary management work. The rejected documents-above-classification layout is not the target.
- [x] Added stable hosts for reviewed input, liquidity movement and Central de Gestão so asynchronous modules coexist without taking ownership of the whole route.
- [x] Added guided bank/card/financing/other document intake under contract `classification-first-guided-document-intake-v1`, with explicit association fields before upload and an optional note for other/manual documents.
- [x] Kept filename non-authoritative and upload non-financial. Real confirmed upload uses private bucket `lts-documents`, then `lts_browser_register_document_v2`; failed registration attempts object cleanup.
- [x] Added 50 MB/format guard, review summary and no-auto-post language; fixture mode disables file/upload and the gate proves `writer_called:false` / `write_accepted:false`.
- [x] Found and fixed same-route target navigation that rerendered `Atualizações` and erased mounted modules. Anchors now open enclosing details and scroll without a full route render.
- [x] Local Chromium desktop/mobile permanent gate, script parsing, button audit 197/197 and candidate smoke: PASS; `index.html` protected hash unchanged.
- [x] Exact remote product `6d2b546b5e32d9ac09013cbd682e261e3f41ccac`, tree `ae4710f80a7ed60c6e0b00c801b9814143edc84a`; exposure `6a25aa99ab9548ef001870d9303d65700a0da8ec`, tree `ebc49406160e31f2d988825392fe642fb35e85df`; all three branches aligned by normal no-force fast-forward.
- [x] Product recovery gate/smoke `34242926042` / `34242925889`, canonical gate/smoke `34243185722` / `34243185837`, main smoke/Pages `34243383377` / `34243381614`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34243737853` / `34243795334` / `34244113857` and Pages `34244111908`: SUCCESS; fixed URL loads exact v1.13 assets with truthful signed-out state, zero iframe and no fixture KPI.
- [x] Artifacts: recovery `10062796446` / `sha256:bb51419f7772a7504b4556bb89d017b8297165d3f01d92f0cb8ff26bd92d1667`; canonical `10062906709` / `sha256:3f19198c6ab8256323cdc7b9b56b19401cd39e0c823322d5c1e5bf5524f99480`.
- [ ] Real authenticated upload→register→lifecycle/readback→interpret/review and physical-iPhone evidence remain open/not claimed.

## P0 — V150 reviewed text-input recovery / canonical v1.12 — 08/09/2026
- [x] Re-audited the V150→canonical line and found a concrete regression: `wip35-v150-recomposition.js` exposed `Lançamento por texto`, while canonical v1.11 documentation claimed the capability but the rendered `Atualizações` route omitted it.
- [x] Restored the capability inside the single canonical frontend with contract `review-before-explicit-apply-v1`: natural phrase → editable preview → required-field review → explicit confirmation.
- [x] Preserved the existing authenticated writer `lts_browser_apply_reviewed_input_v1`, idempotency key and product/cockpit readback; preview never writes, and fixture mode exposes no apply action and never calls the writer.
- [x] Added evidence-limited parsing for relative/explicit dates, known accounts/cards, nature, category/context proposals and the five required value forms: `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Kept bank↔liquidity/RSU movements in the separate reviewed Aplicar/Resgatar flow so they cannot be misposted as revenue or expense.
- [x] Expanded the permanent desktop/mobile gate to verify preview contents, editable fields, missing-evidence warnings, confirmation guard and zero fixture writes while retaining the full v1.11/v1.10/v1.9 regression suite.
- [x] Local Chromium PASS; exact product `70c49b1b50b7faca09b71889e14d33183a7f9092`; fixed-manifest exposure `adac528dbde6d0dcd6268a52c780d3abf43dc9a9`; all three branches aligned by normal fast-forward.
- [x] Product recovery gate/smoke `34235638676` / `34235638646`, canonical gate/smoke `34235911409` / `34235911280`, main smoke/Pages `34236205811` / `34236204118`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34236480960` / `34236541857` / `34236635343` and Pages `34236635451`: SUCCESS; fixed URL resolves to the exact v1.12 product with truthful signed-out state and zero iframe/fixture data.
- [x] Artifacts: recovery `10059792070` / `sha256:db41ecbe329e9166c60241a4461fd33ef963aedd3a7953ac072356cbcc0e3eae`; canonical `10059891042` / `sha256:a84c36b967cba64d524241a19a476d7a9747386046b7bb86799f4b8a328e34eb`.
- [ ] Authenticated real save→readback and physical-iPhone evidence remain explicitly open/not claimed.

## P0 — Layered liquidity evolution / canonical v1.11 — 08/09/2026
- [x] Recovered the explicit 05/09 user requirement that cash evolution show separate account, short-term, RSU and FGTS layers while retaining the liquidity-first V155 visual direction.
- [x] Added a current evidenced anchor from cockpit `through_d3`, a base operational projection from `current_liquidity_balance`, a conditional scheduled-vesting series from `conditional_rsu_balance` and a restricted contingency series from `restricted_total_balance`.
- [x] Kept future vestings conditional and FGTS restricted/D+30; neither can be promoted to observed current cash. Preserved v1.10 documentary commitments and v1.9 V150/V151+ Flow parity unchanged.
- [x] Added explicit legend, accessible chart semantics, four current-composition labels and a regression gate for both charts, all layer/point counts, mobile/desktop panel bounds and the prior full product suite.
- [x] Local Chromium 1312×1199 and 390×844 PASS; visual review found and fixed an FGTS CSS-class collision before release.
- [x] Exact product `8a9c675ed3940da19a10c04e56249a315576045a`; fixed-manifest exposure `04c051f19167e913079bb8e75b692f5fe430892c`; all three branches aligned by normal fast-forward.
- [x] Recovery gate/smoke `34229899061` / `34229899074`, canonical gate/smoke `34230146792` / `34230146827`, main smoke/Pages `34230384306` / `34230382218`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34230610235` / `34230659383` / `34230705729` and Pages `34230705397`: SUCCESS; fixed URL verified on the exact v1.11 asset with truthful signed-out state and zero iframe/fixture data.
- [x] Artifacts: recovery `10057369616` / `sha256:5939e41b70411530e1668546d83764ea48454e72598e0c1e7dc967a0414e87d2`; canonical `10057455711` / `sha256:b3cea9b02272be1495797ed8151fadcda8c3e865929729d648c12e43017aea34`.
- [ ] Authenticated real-data Dashboard verification and physical-iPhone evidence remain explicitly open/not claimed.

## P0 — Dashboard decision truth / canonical v1.10 — 08/09/2026
- [x] Reconciled the approved Dashboard model with the live backend contracts instead of copying illustrative values from the reference image.
- [x] Split both liquidity charts into observed position through `as_of` and dashed projection afterward, using horizon date/status/basis and explicit visual/accessible semantics.
- [x] Removed `work.top_actions` from `Próximos Compromissos`; that panel now consumes only the next card invoice plus rows with an explicit `next_due` from `product.commitments.commitments`.
- [x] Kept classification, card-review and planning tasks in `Atualizações`, preventing operational work from being presented as a financial obligation.
- [x] Added physical commitment→Flow navigation and deterministic assertions for two charts, observed/projected point counts, commitment source, task non-leakage and desktop/mobile overflow.
- [x] Local permanent gate PASS in Chromium 1312×1199 and 390×844; reviewed desktop/mobile evidence preserves the official hierarchy and the V150/V151+ Flow contract.
- [x] Exact product `de4362d90560424a332f77ce22e665729cd7d88f`; fixed-manifest exposure `661be37ea45425a30dd3a35c7605d1921db94559`; all three branches promoted by normal fast-forward.
- [x] Recovery gate/smoke `34225155424` / `34225155422`, canonical gate/smoke `34225365210` / `34225365141`, main smoke/Pages `34225542803` / `34225541791`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34225917363` / `34225967201` / `34226016981` and Pages `34226016118`: SUCCESS; fixed URL verified on exact V1.10 asset with truthful signed-out state and zero iframe/fixture data.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V110_DASHBOARD_DECISION_TRUTH_CHECKPOINT_2026-09-08.md`.
- [ ] Authenticated real-data Dashboard verification and physical-iPhone evidence remain explicitly open/not claimed.

## P0 — V150 Flow interaction parity / canonical v1.9 — 08/09/2026
- [x] Audited release history V150–V160 and located the material regression at V153; V150–V152 retained the richer Flow while V154–V160 solved other visual/data/session concerns without restoring it completely.
- [x] Ported validated behavior into the single canonical frontend without restoring wrapper architecture: inline card-invoice summary/full detail, semantic movement labels, salary-withholding presentation, transfer direction, Hoje, complete next-five-day view and preserved scroll.
- [x] Restored append-only projection actions Editar, Duplicar, Dividir/substituir and Excluir, including 2–12 split parts, validation and live sum; backend contracts remain `lts_browser_flow_event_editor_v1` / `lts_browser_flow_mutate_v1`.
- [x] Preserved later capabilities: `lts_browser_flow_v8`, Consolidado/Itaú/Bradesco/C6, ten period presets, 14 consolidated liquidity/economic columns and purpose-built mobile liquidity layers.
- [x] Expanded the permanent gate to exercise invoice, split, semantics, scroll and mobile Flow overflow; local Chromium desktop 1312×1199 and mobile 390×844 PASS.
- [x] Branch recovery/candidate, canonical/candidate and main smoke/Pages gates pass on exact product `6aba220653a9053cf304ab11bf931db38ccc1b75`; fixed homologation exposure `90aad3a754e69708fcc9e03a5bb32835281e2925` and all post-exposure smokes/Pages are green.
- [ ] Real authenticated invoice/mutation readback, material-data verification and physical-iPhone evidence remain explicitly open/not claimed.

## P0 — Unified Despesas decision workbench / canonical v1.8 — 08/09/2026
- [x] Removed the post-load renderer conflict; `canonical-app` is the sole owner of Despesas and the product module is restricted to Patrimônio/Cartões.
- [x] Combined monthly/yearly history, nature × context/person/cost-center, evidence-led insights, explicit `Não atribuído` semantics and month/item drilldown.
- [x] Permanent gate proves both analytical dimensions and both drilldown directions in Chromium desktop and WebKit mobile, with responsive overflow protection.
- [x] Product package `870acc37f220592c77b488be32315af284b52427`; homologation exposure `352a4fe9716bff063a67dae2e01a0f484d6ac80e`.
- [x] Active/canonical/main gates and Pages green; immutable checkpoint `backups/CANONICAL_APP_V18_UNIFIED_EXPENSES_CHECKPOINT_2026-09-08.md`.
- [ ] Real authenticated expense readers and physical-iPhone E2E remain pending/not claimed.

## P0 — Route/session continuity + unified DoD receipt — 08/09/2026
- [x] Resolve the intended canonical route from URL/session before the first RPC and first product render; persist navigation state only, never financial data.
- [x] Preserve route intent across refresh, signed-out login, future-JWT safe reset, browser back/forward and bfcache; canonicalize direct deep links and invalid-route fallback.
- [x] Persist and restore the eight valid Central de Gestão panes without adding another primary mobile route.
- [x] Generate `lts-canonical-definition-of-done-receipt-v1` in the permanent browser gate, with requirement-by-requirement status and honest claim boundaries for authenticated data/writes, physical iPhone and public promotion.
- [x] Exact product target `e618ef48e22872ce718c7932872e2316e5660f67`; exposure `33da29ab0818c9dd59dca45f68d3680ed153f6af`.
- [x] Recovery/candidate `34190659782` / `34190659780`, canonical gate/candidate `34191017877` / `34191017858`, main candidate/Pages `34191216218` / `34191215874`: SUCCESS.
- [x] Receipt artifact `10042106418`, digest `sha256:69ef7f8af36374e9c91ae5074690d13525676d8fe8ee326024c40e381e36ed47`; Chromium 1312×1199 and WebKit 390×844 suites PASS.
- [x] Post-exposure active/canonical/main smokes `34191461669` / `34191462282` / `34191463017` and Pages `34191462402`: SUCCESS.
- [x] Fixed URL browser-verified at the exact target with continuity-v7 asset, clean login, zero unauthenticated financial KPIs and no iframe.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V17_ROUTE_SESSION_DOD_RECEIPT_CHECKPOINT_2026-09-08.md`.
- [ ] Receipt rows that require authenticated real data/writes and physical-iPhone evidence remain open; automatic PASS does not claim final delivery.

## P0 — Dashboard Fidelity Pass 6 — 08/09/2026
- [x] Recovered the approved-reference desktop navigation order without creating fake product ownership: Dashboard, Fluxo Diário, Despesas, Receitas, Cartões, Patrimônio, Planejamento, Atualizações, Relatórios, Documentos and Configurações. `Receitas` resolves to the evidenced Flow rather than inventing a new ledger.
- [x] Added month/as-of controls and a working `Hoje` reload while preserving the five liquidity-first KPIs and honest missing-data behavior.
- [x] Added evidence labels for account count, D0, D+3, D+30 and reliable month comparison; the comparison is withheld when the backend does not certify it.
- [x] Added working bank rows and Dashboard drill-downs into Flow, Despesas, Patrimônio, Atualizações and Planning/Central de Gestão.
- [x] Preserved all ten v1.6 briefing capabilities and fixed delayed remounts that could erase a selected mobile scenario.
- [x] Exact product target `9ae0ee37ab3332415523eeee287cdbf75102e1c4`; exposure `4d3c7bc912a672ae7353c7028d8b05d047961dd5`.
- [x] Recovery/candidate `34185954453` / `34185954506`, canonical gate/candidate `34186087590` / `34186087628`, main candidate/Pages `34186301851` / `34186300869`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34186663110` / `34186664337` / `34186664887` and Pages `34186664347`: SUCCESS.
- [x] Visual evidence reviewed at 1312×1199 and 390×844; URL fixa browser-verified with Pass 6 assets, clean login, zero unauthenticated KPI cards and no iframe.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V161_DASHBOARD_FIDELITY_PASS6_CHECKPOINT_2026-09-08.md`.
- [~] Continue evidence-led pixel/detail convergence and real-data richness; pixel-perfect parity and authenticated physical-iPhone E2E remain unclaimed.

## P0 — Supabase RLS / SECURITY DEFINER hardening — 08/09/2026
- [x] Audited the 13 RLS-disabled tables and the client-executable SECURITY DEFINER surface; the decisive exposure was 12 internal Flow/cache helpers accepting an arbitrary `user_id`, not direct table grants.
- [x] Applied migration `20260908045049 canonical_security_rls_and_flow_helper_acl_2026_09_08`: RLS on all 13 internal tables, client table grants revoked, 12 helpers internal-only and Flow browser wrappers v7-v10 authenticated-only.
- [x] Hardened future postgres-owned defaults in `public`: zero default function/table/sequence grants remain for `PUBLIC`, `anon` or `authenticated`; `service_role` access is preserved.
- [x] Postflight: 13/13 tables with RLS and no direct client DML, 12/12 helpers closed, 4/4 wrappers authenticated-only, zero anonymous SECURITY DEFINER reachability and zero authenticated SECURITY DEFINER functions without a direct allowlist/JWT/user guard.
- [x] Transactional authenticated rollback regression passed for Flow v8, Dashboard cockpit and the product contract.
- [x] Security Advisor rechecked: no RLS-disabled or anonymous SECURITY DEFINER findings. Its 13 new no-policy INFO notices represent intentional deny-by-default internal tables; 65 signed-in SECURITY DEFINER warnings map to guarded browser RPCs.
- [ ] Enable/review leaked-password protection under a controlled Auth change window; this provider setting was not changed by the database migration.
- [x] Immutable checkpoint `backups/CANONICAL_SUPABASE_RLS_SECURITY_DEFINER_HARDENING_CHECKPOINT_2026-09-08.md`.

## P0 — briefing capability recovery / canonical v1.6 — 07/09/2026
- [x] Converted the recovered secondary-capability inventory into one navigable Central de Gestão inside `Atualizações`, while preserving the six-route mobile contract.
- [x] Exposed all ten required capabilities: Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.
- [x] Wired real authenticated browser contracts for planning, recurrence audit, read-only vesting scenario, backup status/export, staged restore, Open Finance status, wealth detail and document lifecycle.
- [x] Preserved guardrails: no future FGTS accrual, recurring history never auto-creates facts, scenarios remain read-only, reconciliation target is R$0, backup payload is separate/private, restore requires checksum + preview + exact phrase + second confirmation.
- [x] Exact product target `501fb48265b02a5416f0fc198a54abf8688ddd14`; homologation exposure `39689a3ba6648eeb633cddec8feee26b7d8f6766`.
- [x] Active recovery/candidate `34179625830` / `34179625805`, canonical gate/candidate `34179823179` / `34179823167`, main candidate/Pages `34179954294` / `34179953893`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34180090300` / `34180147055` / `34180249928` and Pages `34180249315`: SUCCESS.
- [x] Desktop/mobile evidence reviewed; no horizontal overflow and all six primary mobile destinations preserved.
- [x] Fixed homologation browser-verified at exact target `501fb482...`, capabilities loader and truthful unauthenticated login.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V161_BRIEFING_CAPABILITY_RECOVERY_CHECKPOINT_2026-09-07.md`.
- [ ] Authenticated real-data/write/backup-restore lifecycle E2Es remain pending and must not be inferred from fixture gates.

## P0 — iPhone session recovery + durable requirements audit — 07/09/2026
- [x] Reproduced the real-device failure class `JWT issued at future` with a persisted future-token session in WebKit 390×844.
- [x] Centralized bounded retry, one coalesced refresh and safe session reset; raw JWT detail is no longer rendered to the user.
- [x] Product target `abe6180d37657cc47bf18036f524a95ff262df13`; exposure `0643f57e2b2b89b8cbf3ea6ba3c58296b4614ebd`.
- [x] Active recovery/candidate `34174520963` / `34174520971`, canonical gate/candidate `34174620205` / `34174620102`, main candidate/Pages `34174717328` / `34174716172`: SUCCESS.
- [x] Post-exposure active/canonical/main candidate smokes `34175144495` / `34175143351` / `34175143758` and Pages `34175143251`: SUCCESS.
- [x] Fixed homologation browser-verified at exact target `abe6180...`, with `canonical-liquidity.js?v=20260908-session6` and truthful clean-session login.
- [x] Recovered briefing, Dashboard lineage, V150/V151 scope and validation classes consolidated in `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md`.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V157PLUS_IPHONE_SESSION_RECOVERY_CHECKPOINT_2026-09-07.md`.
- [ ] Authenticated physical-iPhone post-fix/data E2E remains pending and must not be claimed.
- [x] Audit every briefing capability not represented as a primary canonical route; grouping is allowed, silent removal is not.

## P0 — Dashboard Fidelity Pass 5 — 07/09/2026
- [x] Removed the post-load simplified Dashboard replacement; the dense canonical Dashboard is again the single owner of that route.
- [x] Preserved the five liquidity-first KPIs while restoring the approved-reference section density: liquidity evolution, asset distribution, bank position, cash flow, top expenses, commitments, planning, FGTS and pending updates.
- [x] Product source `6eca5c3785cd5dca69a2aa8f610312eefbb2a669`; exact gated target `eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d`; exposure `a808d855aa6687a893a51598db8f5fad4faf1cbb`.
- [x] Recovery `34173223977`, permanent canonical `34173482173`, final active/canonical/main smokes `34173481335` / `34173482194` / `34173586238`, and Pages `34173586282`: SUCCESS.
- [x] Post-exposure active/canonical/main smokes `34173674961` / `34173674230` / `34173673390` and Pages `34173673353`: SUCCESS.
- [x] Fixed homologation browser-verified at the exact gated target with Pass 5 asset and truthful unauthenticated login.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V157PLUS_DASHBOARD_FIDELITY_PASS5_CHECKPOINT_2026-09-07.md`.
- [x] Superseded as the current visual baseline by Dashboard Fidelity Pass 6; Pass 5 remains immutable evidence.

## P0 — V157+ product-recovery exposure — 07/09/2026
- [x] Canonical V157+ split modules are the permanent product line: `canonical-liquidity-core.js`, `canonical-flow-v157.js`, `canonical-product-v157.js`, `canonical-presentation-v157.js`.
- [x] Product/gate implementation `76f888dc0e668fb0e768c8cc825f56778f043f50`; gated manifest target `c44d401497e14d842d433a302006ff5648b956a9`; exposure commit `3b3048fa4660868e161582fcd8704438a13e300c`.
- [x] Modular recovery gate `34170935882`, permanent canonical gate `34171231918`, active/canonical/main candidate smokes `34170935887` / `34171231935` / `34171338575`, and Pages `34171338335`: SUCCESS.
- [x] Post-manifest active/canonical/main candidate smokes `34171452083` / `34171452913` / `34171453488` and Pages `34171452759`: SUCCESS.
- [x] Fixed homologation resolves to the exact gated V157+ baseline and was browser-verified with canonical script + truthful unauthenticated login.
- [x] Historical v144–v160 workflow batteries no longer auto-trigger on `main`; feature-branch and manual execution remain available as historical evidence.
- [x] Immutable checkpoint `backups/CANONICAL_V157PLUS_PRODUCT_RECOVERY_EXPOSURE_CHECKPOINT_2026-09-07.md`.
- [x] Public `index.html` remains protected and unchanged; `promotion_status:not_promoted`.
- [ ] Authenticated physical-iPhone financial/data E2E remains pending and must not be claimed.
- [~] Remaining evidence-led Dashboard refinement, security hardening and authenticated lifecycle proof remain active P0.

## P0 — current canonical functional baseline — 06/09/2026
- [x] Wrapper line v154→v160 is historical only; it is no longer the primary product architecture.
- [x] Single canonical frontend exists at `canonical-app.html`; no iframe/release-wrapper chain is part of the canonical product.
- [x] Canonical app owns Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações.
- [x] Direct Supabase authentication/RPC layer; unauthenticated state exposes the real login rather than synthetic financial content.
- [x] Official-reference Dashboard language/density and liquidity-first hierarchy preserved.
- [x] Functional app source commit `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`; 79,339 bytes; SHA-256 `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`.
- [x] Deterministic functional gate `34003647351`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- [x] Gate covers five KPIs, six physical routes, Fluxo account switching, Despesas nature×context + drilldown, Patrimônio, Cartões, Atualizações search/CSV/classification/documents, no iframe, no overflow/clipping, no page errors and truthful unauthenticated fallback.
- [x] Gate artifact `9980249754`; visual evidence includes canonical Dashboard desktop/mobile and Atualizações.
- [x] Fixed homologation moved to `canonical-v1` / `canonical-app.html`; `promotion_status:not_promoted`.
- [x] Canonical exposure commit `e6f3ab7421d5b7cb1986df768835f9d826536d9d`; exact Pages deployment `34003976631`: SUCCESS.
- [x] Immutable checkpoint `backups/CANONICAL_APP_V1_FUNCTIONAL_HOMOLOGATION_CHECKPOINT_2026-09-06.md`.
- [x] Public `index.html` remains protected and unchanged; public promotion is NOT authorized.
- [x] Canonical Atualizações now exposes reviewed Aplicar/Resgatar bank↔cash-investment preview with explicit account/asset/value/date, equal-and-opposite legs, R$0 economic effect, explicit confirmation and post-write readback.
- [x] Liquidity UI deterministic gate `34053651814`: SUCCESS on Chromium desktop + WebKit mobile; artifact `9995321790`; checkpoint `backups/CANONICAL_APP_V1_LIQUIDITY_UI_GATE_CHECKPOINT_2026-09-06.md`.
- [ ] Real authenticated liquidity save→refresh→visible remains pending because deterministic fixture never posts financial facts.
- [ ] Authenticated physical-iPhone financial/data E2E of the canonical app remains pending and must not be claimed.

## Historical release evidence retained
- [x] v154 established accepted official-reference visual direction.
- [x] v155 corrected false-zero/navigation defects but later showed runtime slowness.
- [x] v156 established liquidity-first Dashboard but failed real iPhone data/navigation.
- [x] v157 WebKit recovery passed deterministic gates but failed real-device evidence.
- [x] v158 restored truthful native/auth fallback but regressed product presentation.
- [x] v159 restored presentation but real iPhone still showed unavailable KPI data.
- [x] v160 made readiness material-data driven and remains a historical technical fallback only.

## P0 — FGTS / planejamento under current conservative rule
- [x] Latest exact documentary FGTS balance **R$22.432,31 at 21/08/2026**.
- [x] FGTS restricted / approximately D+30 when accessible, never D+3 cash.
- [x] No future FGTS deposit/accrual estimation.
- [x] Current audited planning separates request/action/gap: request FGTS by 30/11/2026; management/action point 30/12/2026; first uncovered gap 30/01/2027.
- [x] Current audit: bank cash R$15.794,43; D0 R$42.929,50; vested D+3 R$12.909,65; through D+3 R$71.633,58; worst before FGTS -R$25.782,39; worst after current documentary FGTS -R$3.350,08.
- [x] Migration `dashboard_planning_first_negative_alias` normalizes the first-negative field without changing financial arithmetic.
- [x] Historical R$3.700/month accrual and dependent R$32.309,05 request-date/worst-case outputs are historical evidence only.

## 0. Release / homologation guardrails
- [x] Public root `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [ ] Never force branch history or overwrite parallel work.
- [ ] Before every repository write, re-fetch `main`, active branch, this backlog, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and latest immutable checkpoint.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual/data E2E unless actually performed.
- [ ] Preserve fixed links, mobile/desktop usability, backup and traceability through every release.

## 1. Dashboard / planejamento incorporado
- [x] Product framing `Sua vida financeira, em uma tela.`.
- [x] Liquidity-first hierarchy: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês).
- [x] `Contas + curto prazo` arithmetic evidence-only: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist; missing evidence stays unavailable.
- [x] FGTS separate/restricted; future RSUs excluded before vest/settlement.
- [x] Planning displays distinct management/action and first-negative fields.
- [x] Dashboard fidelity pass 1 gated in run `34056854438` on Chromium desktop 1312×1199 + WebKit mobile 390×844; artifact `9996230152`; checkpoint `backups/CANONICAL_APP_V1_DASHBOARD_FIDELITY_GATE_CHECKPOINT_2026-09-06.md`.
- [~] Dashboard visual parity with the approved 1312×1199 official reference remains P0: continue real-data visual richness, navigation/detail refinement and chart presentation without fake modules or synthetic user-facing financial series.
- [ ] Any new money-changing assumption/scenario requires explicit user decision unless already explicitly stated.

## 2. Despesas — natureza × contexto/pessoa
- [x] Economic invariant R$8.623.752,53 preserved.
- [x] Analytical cache 3.860/3.860, zero mismatch.
- [x] Nature and context/person/cost center remain distinct analytical dimensions.
- [x] Canonical app consumes `lts_browser_expense_context_lens_v1`.
- [x] Periods: current year, 12 months, since 2023, since 2013 where supported.
- [x] Context→nature and nature→context read-only drilldown exists in canonical route.
- [x] `Não atribuído` distinguishes documentary detail missing, system investigation and classification/context pending.
- [~] Continue improving density, ranking and decision-useful insights from real evidence.
- [~] Reduce `A classificar` only by evidence, never invention.

## 3. Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.

- [x] Merchant research never invents purchase purpose.
- [x] Marketplaces/intermediaries remain manual where actual purchase purpose is unproven.
- [x] Writer `lts_browser_semantic_feedback_v1`; reader `lts_browser_product_v1`.
- [x] Canonical lifecycle wiring performs save → product refresh/read verification and supplies resolved/pending feedback; fixture writer disabled by design.
- [ ] Real authenticated classification save→refresh→resolved disappearance/self-heal remains pending.

## 4. Atualizações / Input / documents / transaction search
- [x] Atualizações classification-first: classification remains foreground; `Outras ações que precisam de você` is collapsed and contains documents/secondary work.
- [x] `Lançamento por texto` keeps preview/review semantics; no automatic posting.
- [x] Date/value/account-or-card mandatory before approval; liquidity/RSU movements are not revenue/expense.
- [x] Server-side incremental transaction search through `lts_browser_transactions_v1` implemented in canonical frontend.
- [x] Supported scope: 10/10/2013 onward plus future launches already present in LTS.
- [x] Search read-only, total exposed, Excel-compatible CSV with available date, description, account, direction, amount, category, counterparty, cost center and source/reference.
- [x] Backend evidence for `Mastercard`: 239 rows spanning 01/11/2013–12/04/2028.
- [ ] Real authenticated transaction-search E2E remains unclaimed; deterministic functional search/CSV gate is complete.
- [x] Explicit document association preserved: statement→account/institution+competence; card statement→card+competence; financing→commitment+exact as-of; other docs→manual review.
- [x] Filename never determines account/card/competence/date/value; upload alone never posts financial data.
- [x] Interpretation separates user-provided linkage from extracted reading; extraction remains evidence only.
- [x] Canonical Atualizações provides guided private upload, registers through `lts_browser_register_document_v2`, consumes `lts_browser_document_lifecycle_v1` and attempts Storage cleanup if registration fails.
- [ ] Real authenticated PDF/image upload→register→lifecycle/readback→interpret→review remains pending/unclaimed.

## 5. Fluxo Diário / FIX86
- [x] Mandatory Consolidado, Itaú, Bradesco, C6; history from 2013 where supported.
- [x] Canonical Fluxo owns account switching without nested wrappers.
- [x] `Saldo anterior | Entradas | Saídas | Saldo final`; balances visually differentiated.
- [x] Facts beat projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- [x] Bank↔liquidity-asset transfer consolidated economic effect zero.
- [x] Restore inline reconciled card-invoice detail without counting payment plus purchases twice.
- [x] Restore semantic movement labels, transfer direction, net-salary evidence, Hoje/five-day behavior and scroll preservation.
- [x] Restore append-only edit/duplicate/split/cancel projection actions; fixture gate cannot write.
- [x] Never infer historical bank without evidence; absent balance remains unavailable.
- [ ] Real authenticated physical-device visual/data E2E remains open.

## 6. Natural liquidity input / mutation contract
- [x] Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account/asset; preview both legs/before-after/economic effect R$0; explicit confirmation before write.
- [x] Canonical Atualizações UI now implements application/redemption selection, backend options, preview, confirmation/idempotency and post-write product/cockpit readback; fixture writer is disabled.
- [ ] Authenticated liquidity save→refresh→visible remains pending.
- [x] Append-only edit/cancel/split semantics proven: current-event operations append to `lts_flow_event_operation`; legacy overrides append to `projecao_op`; mutation audit appends to `lts_flow_mutation_audit`; source facts are not destructively rewritten.
- [x] Effective readers apply latest active operation and cancelled/split originals do not reappear as effective facts.
- [x] `lts_fix86_legacy_guardrails_qa_v4`: 10/10 PASS, including `flow_mutations_append_only_operational`.
- [ ] Separate user-facing undo/reversal action remains disabled until an explicit append-only reversal contract is implemented. Do not conflate this with already-proven cancellation semantics.

## 7. Cartões / historical recovery
- [x] Canonical Cartões consumes `lts_browser_card_history_coverage_v1`.
- [x] Certified allocation 38 cycles / 650 rows / R$885.855,19.
- [x] Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- [x] C6 Aug/2024 category R$4.087,42 vs detail R$4.020,72; explicit R$66,70 gap.
- [x] Mastercard 2022 certified Apr/Jun/Jul/Oct; remaining months need evidence.
- [~] Mastercard 2023: 12 ledger-only payments / R$496.689,05; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; others incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [x] Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- [~] Continue Mastercard/Visa recovery only from documentary evidence; never pattern-fill purchases.

## 8. Patrimônio / RSU / CIPÓ / Volvo
### RSU
- [x] Canonical Patrimônio consumes `lts_browser_wealth_detail_v1`.
- [x] Current documentary position at 03/09/2026: **184,483 Organon shares / R$12.909,65 / D+3**.
- [x] Prior 18/08/2026 snapshot: **459,483 shares / R$32.772,30**; historical only, not current vested KPI.
- [x] Current position metadata records a 275-share reduction after the prior snapshot and user-confirmed sale.
- [x] Brokerage cash R$2.862,67 at 03/09/2026 separately recorded as `available_unclassified`; excluded from D0/D3 until transfer latency is evidenced.
- [ ] Exact trade settlement date/price/proceeds for the 275-share reduction remain pending documentary reconciliation.
- [ ] Historical sale proceeds/details where not evidenced remain unitemized; do not assert unsupported quantity/gross/fees/FX.

### FGTS temporal distinction
- [x] 21/04/2026 R$25.585,03 and 07/05/2026 full withdrawal are historical positions.
- [x] 21/07/2026 R$17.509,05 intermediate position.
- [x] 21/08/2026 R$22.432,31 latest documentary balance.
- [x] Keep temporal positions distinct; do not sum snapshots.
- [x] No future FGTS accrual estimation.

### CIPÓ 396
- [x] Drilldown exposes purchase/history/reforms/debt/market/equity/schedule where evidence exists.
- [x] Ledger audit establishes separate actual consortium entries: R$6.654,50 on 12/05/2023 and R$151,80 on 15/05/2023; never describe them as same-date documentary arithmetic.
- [ ] Itaú/consortium delta R$303,60 unresolved; recovered R$303,60 Visa Infinite rows are not valid consortium evidence.
- [ ] Condominium formula/cutoff lacks source.
- [ ] Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70 unresolved.
- [ ] Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.

### Volvo
- [x] Bradesco financing 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically.
- [ ] Exact trim/version and km required before valuation refinement.

## 9. Open Finance
- [x] Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- [x] `lts_browser_open_finance_status_v1` exposes provider-neutral connection/sync health; staged data must reconcile before canonical financial effect; LTS tables do not store bank credentials/provider secrets.
- [~] Need written pricing, support/SLA, exact data scope and product×bank coverage for Itaú/Bradesco/C6, historical depth, refresh/webhook support, consent renewal, errors and sandbox quality.
- [ ] No provider consent/spend/credential/commercial commitment without explicit user decision.

## 10. Backend QA / stability / performance
- [x] Historical backend fingerprint `85a1b60816a5b84dfe3b41341ed27948` retained as baseline evidence.
- [x] v14 293/293; v15 67/67; v16 19/19; v17 32/32; staged 411 checks / 35 suites + supplemental v143 16/16.
- [x] v146 historical navigation regression: 140 physical clicks.
- [x] Canonical gate `34003647351` covers single-frontend Chromium/WebKit functional behavior and truthful no-fixture auth fallback.
- [x] Canonical liquidity UI gate `34053651814` additionally covers Aplicar/Resgatar preview and remains green on Chromium/WebKit.
- [x] Canonical Pages exposure deployment `34003976631`: SUCCESS.
- [x] Current transversal legacy guardrail QA `lts_fix86_legacy_guardrails_qa_v4`: 10/10 PASS.
- [x] Supabase RLS/ACL hardening applied and contract-regressed: 13/13 audited tables protected, 12/12 arbitrary-user helpers internal-only, guarded browser RPC boundary preserved and secure object defaults installed.
- [ ] Enable/review leaked-password protection under a controlled Auth change window; continue reviewing every newly introduced signed-in SECURITY DEFINER function against the guarded browser-RPC rule.
- [ ] Authenticated physical-device financial/data E2E remains open and explicitly unclaimed.
- [~] Continue performance work after correctness/parity; search already uses server-side filtering rather than broad fetch.

## 11. Historical continuity / backups / product quality
- [~] Continue audit back to project start 07/07/2026 so no pending item disappears.
- [x] Recovered and versioned the material 24/08, 04–05/09 and 07/09 feedback covering Flow controls/invoice semantics, V155 Dashboard hierarchy/layers, real-device failures and V150 as the functional floor.
- [x] Preserve historical evidence from 2013 where supported.
- [x] Preserve fixed public/homologation links and canonical backup/restore traceability.
- [x] Canonical deterministic evidence preserves official-reference Dashboard language, compact Atualizações and mobile/desktop no-overflow behavior.
- [~] Continue real-data/product-quality refinement without reintroducing wrapper chains.

## 12. Current user-dependent decisions / blockers
- [ ] Authenticated physical-iPhone financial/data E2E of canonical app when material real-device validation becomes the final gate.
- [ ] Human classification only where evidence remains insufficient.
- [ ] New money-changing assumptions not already explicitly supplied by the user.
- [ ] User-facing undo/reversal semantics beyond the proven append-only cancel/edit/split contract.
- [ ] Provider/commercial/consent decision for real Open Finance activation.
- [ ] Public-root promotion remains a user decision; Supabase policy hardening itself is engineering work and must proceed autonomously after contract-level design/tests.

No other engineering task should wait for the user.
