# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Completed evidence remains under `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `NEXT_HOMOLOGATION_GATE.md` and `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`. Never remove an open financial/documentary dependency during compaction.

## P0 — real-user recovery 30/08/2026
- [x] Real user review rejected v141 as a visual/product candidate in **Atualizações, Patrimônio and Planejamento**. Despesas is closer to the desired direction but still not final. This supersedes any earlier wording that treated those surfaces as visually homologable merely because parser/smoke gates were green.
- [x] Recovered the earlier executive Planning information architecture from project artifacts: fast liquidity story, current vs future-resource coverage, `ponto de gestão` vs `falta real`, RSUs that change cash, account-level need and few prioritized actions. This is the UX reference; implementation/QA language must not dominate the page.
- [~] **P0 Planning Excel→current bridge audit** opened in `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`. Current engine internally reaches R$-21,046.80 after scheduled RSUs in Jan/2027 and R$-3,537.75 under the static FGTS overlay, while the user recalls no real shortage after RSUs+FGTS in the Excel model. Do not treat either side as authoritative until anchors, future events, RSU timing/valuation, FGTS timing and post-Excel factual changes are bridged row by row.
- [~] Restore one obvious **natural-language launch surface** for everyday financial input. Expense/income can reuse the existing reviewed writer. Redemption/application must be a dedicated liquidity movement path that updates bank/asset semantics without being classified as income/expense and without double economic effect.
- [~] **Atualizações** must return to compact checklist/action-first UX. Classification review is a separate, dense queue ordered by objective priority; no giant whitespace-heavy cards and no unsafe category suggestion.
- [~] **Patrimônio** must be executive-first: what is owned, what is owed, equity, current liquidity, restricted/future resources, then expandable evidence/detail. No technical-data dump as primary view.
- [~] `wip35-v142-candidate.html` was created as a UX recovery work candidate at commit `28557e02711907060cc78c54176d51fc11e09ba2`, but it is **not validated and must not be pointed to by `homologacao-current.json` yet**. Smoke scripts/workflow still target v141 and must be upgraded before any user test.
- [ ] Do not ask the user to test again until this P0 package is coherent, parser/smoke/Pages/heavy gates are green, and the Planning discrepancy is either explained or explicitly isolated as an unresolved financial blocker.

## 0. Release / homologation
- [x] Public `index.html` remains WIP35-v136 fallback; exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` guarded. v136 is not user-approved; effective prior visual baseline v135.
- [x] v137 failed real homologation; v139 failed real authenticated boot because lexical v136 state was treated as `window.*`; synthetic-readiness smoke retired.
- [x] v140 added lexical bridge and early Flow-v4 routing; user confirmed real mobile boot.
- [x] v141 version-ownership race fixed; document-outcome package at `3afecdccfc480b8719bc11fd7170671f8d30b3c1` had candidate-smoke run `33323180487` SUCCESS and same-head Pages run `33323179920` SUCCESS.
- [x] Fixed homologation entrypoint is `homologacao.html`; it loads `homologacao-current.json` with `no-store` + timestamp cache busting and redirects to the currently validated candidate. The user keeps one URL across future candidate versions.
- [x] Homologation-entrypoint gate head `ff3107947cdf8dc34ea7dcddc284c07ec6daad86`: fixed-entrypoint validation, parser and Chromium desktop/mobile all SUCCESS in candidate-smoke run `33325382391`; same-head Pages run `33325382173` SUCCESS. Manifest still targets validated v141 until a successor is green.
- [x] Public fallback unchanged; no promotion occurred.
- [~] Upgrade candidate smoke from hardcoded v141 to v142-chain validation before changing the homologation manifest.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] Promotion to `index.html` only after user homologation.
- [ ] Do not ask user for basic QA; next request must be material authenticated visual homologation or a genuine user decision.

## 1. Executive UX / candidate
- [x] Despesas and Fluxo timeout paths replaced by exact-parity cache-backed reads.
- [x] Fluxo v141 removes duplicate internal `Hoje` button while retaining the period chip, and restores subtle balance-cell emphasis on mobile/desktop; parser + Chromium + Pages green.
- [x] Atualizações has evidence-derived document outcomes: Alterou / Sem alteração / Precisa decisão / Processando / Erro, separate from `O que mudou`.
- [x] Configurações shows metadata-only backup status.
- [~] Planning: rebuild from recovered executive IA and only surface conclusions supported by the Excel→current bridge audit.
- [~] Patrimônio: rebuild executive summary; preserve CIPÓ/Volvo/evidence guardrails behind a clear first layer.
- [~] Atualizações: recover checklist/action hierarchy and compact classification review.
- [~] Despesas: preserve current direction and refine density/insights/drilldown after the three rejected surfaces are stabilized.
- [~] Classification triage backend is ready/gated; integrate as review-order UX only in a coherent classification package, not as a category suggestion.
- [~] Document association backend is ready/gated; integrate explicit bank/card/competence fields into guided upload without filename inference.
- [~] Visual approval of Fluxo, Despesas, Cartões, Planejamento, Atualizações, Patrimônio and Configurações pending.
- [~] Continue checking mobile overflow, empty states and action hierarchy.

## 2. Atualizações / inputs / documents
- [x] Checklist-first maintenance, upload, bank/card/financing/salary/IPVA checks and manual invoice update exist in the underlying product history.
- [x] Operational resolutions append-only; lifecycle v2 + `O que mudou`; writer→refresh/safety QA 9/9 PASS.
- [x] Inbox preapproval guard: manual review entry has no financial write; write occurs only through explicit reviewed approval path.
- [x] Documented card purchase remains separated from bank cash effect before invoice reconciliation.
- [x] Document outcome semantics QA 4/4 PASS; auth.uid-scoped browser ACL 4/4 PASS; anon blocked and internal arbitrary-user contracts private.
- [x] Explicit file association contract exists for PDF/photo/file only; card/bank association requires explicit identity + competence, financing requires explicit commitment + as-of date; filename/similarity inference is forbidden. QA 5/5 PASS.
- [~] Restore a single obvious launch/import area rather than forcing the user to discover a hidden minor tab.
- [~] Reconnect natural-language reviewed input for expense/income in the visible Atualizações workflow.
- [~] Design/implement safe redemption/application writer with explicit bank + asset legs, append-only audit and no expense/income classification; test before exposure.
- [~] Guided UI still needs to collect/pass explicit bank/card/competence context so more document review becomes exception-only.
- [~] Real authenticated resolved-item disappearance/save-refresh/self-heal/`O que mudou`/outcome path pending.
- [~] Improve PDF/image interpretation; visual extraction remains unavailable without an external extraction service, so manual review remains the safe fallback.
- [~] Final review should become exception-only as parser/document coverage improves.

## 3. Despesas
- [x] Historical expense invariant R$8,623,752.53 from 10/10/2013 preserved.
- [x] After 2022 recovery cache closes 3,860/3,860 analytical rows, zero missing/extra/mismatch; economic total unchanged.
- [x] YTD cache ~0.1s versus ~29s old path; permanent <1500ms guard.
- [x] Month/year/rolling comparisons, rankings/trends, drilldown and documentary merchant/counterparty lens exist; no merchant fabrication from category-only/aggregate history.
- [x] Expense v9 19/19; Expense v10 18/18; documentary counterparty QA 4/4 PASS.
- [x] Day rollover refreshes Despesas cache if stale.
- [~] Real user review 30/08: direction improved and closer, but refinement remains open; do not regress while fixing other surfaces.
- [~] Real authenticated visual retest pending.
- [~] Reduce unclassified/unassigned only with evidence.

## 4. Fluxo Diário / FIX86
- [x] Flow v12 canonical; browser Flow v4 authenticated/cache-backed; shared annual Flow parity exact.
- [x] Historical effective parity v2: 2,030 days / 147 months and annual comparisons exact through 2025; timeline 57/57; zero technical leak/overlap.
- [x] FIX86 transversal QA v4 = 10/10 PASS: frozen baseline, stale-anchor exclusion, Inbox isolation, nonrecursive estimates, read-only scenarios, append-only mutations, core no-double-count and CIPÓ parity.
- [x] Flow edit/cancel/split never destructively updates source facts.
- [x] v141 mobile/desktop saldo emphasis and single `Hoje` control technically green on candidate smoke + Pages.
- [~] Planning audit must prove that projected Flow components match the Excel bridge; an internally consistent Flow is not sufficient evidence of economic parity.
- [ ] Final authenticated visual E2E.

## 5. Planejamento
- [x] Intended liquidity order cash → D0/D1 → vested RSU D3 → conditional vestings → FGTS ~D+30 contingency.
- [x] Current motor output: 5 layers, 3 negative episodes; first scheduled-RSU gap 08/01/2027; worst R$-21,046.80; prior UI computed FGTS request-by 09/12/2026; v131 12/01 counterfactual preserved.
- [x] Planning QA 23/23 PASS proves internal contracts; it does not close Excel→current economic parity.
- [~] P0 audit `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`: reconcile old Excel `Saldo Ex RSUs` / `Saldo Ex FGTS` / `Saldo Total` / `Saldo Futuro`, anchors, monthly events, RSU vesting/settlement and FGTS timing.
- [~] Classify each negative point in UX as one of: account redistribution, liquidity management point, or real insufficiency. Do not label all negatives as “falta de dinheiro”.
- [~] Restore executive, fast-reading layout based on recovered Claude-era reference; remove implementation/QA jargon from primary view.
- [~] Visual homologation pending only after audit closes or the exact unresolved financial difference is isolated.
- [ ] New assumption/scenario changing money requires explicit user decision.

## 6. Cartões / historical validation
- [x] Open actual bill separate from future installments; 3 open cycles / 153 historical months.
- [x] Certified historical allocation: **38 cycles / 650 rows / R$885,855.19**.
- [x] Aggregate fallback: **314 rows / R$2,650,846.36**; dynamic coverage QA v2 8/8 PASS; zero certified/fallback overlap.
- [x] Global fallback inventory v1 covers **31 instrument×year blocks**; 7 registry-tracked and 24 aggregate-only documentary gaps; QA **5/5 PASS**.
- [x] Two non-Mastercard P1 gaps are explicit: **Visa 2017 R$126,681.76** and **Visa Infinite Itaú 2024 R$112,253.01**; priority is diagnostic only and authorizes no inferred reconstruction.
- [x] File Library source recheck confirmed the 12 Visa 2017 settlement totals and Visa Infinite Itaú monthly 2024 settlement totals; neither result contains a complete category matrix, so no promotion.
- [x] Visa Infinite Itaú 2025 = 12/12 exact.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; Jan/Feb/Apr/Jun/Jul/Nov exact settlement but composition missing.
- [x] Mastercard 2022 newly certified exact: Apr R$11,910.91; Jun R$10,185.54; Jul R$13,486.29; Oct R$28,374.06.
- [x] Historical registry v4 tracks **68 open Mastercard cycles 2019–2025**, internal-only; QA **16/16 PASS**.
- [x] 2019 ledger-only total R$164,402.94 / 12 months; 5 fragmented months.
- [x] 2020 ledger-only total R$99,107.08 / 12 months; 10 fragmented months.
- [x] 2021 ledger-only total R$116,458.47 / 12 months; 12 fragmented months.
- [~] 2022 remaining: Jan–Mar fragmented; May/Aug/Sep/Nov/Dec partial documentary candidates. Dec/2022 source rows were re-found in `Cartão Itaú`, but retrieval still truncates before a complete signed tail, so it remains un-certified.
- [~] 2023: 12 ledger-only payments / R$496,689.05; independent category matrix missing; latest targeted retrieval failed before content and changed no status.
- [x] C6 Aug/2024 category total certified; individual-detail gap R$66.70 explicit.
- [~] File Library retrieval is intermittent; retrieval failure != evidence absence and partial snippets != complete documentary composition.
- [~] Extend documentary recovery to global fallback inventory by evidence/impact only; no pattern backfill.
- [~] Visual homologation pending.

## 7. Patrimônio / CIPÓ 396
- [x] Financial model separates market estimate, documentary debt, equity, liquid/restricted assets and future awards; Wealth QA 18/18 PASS.
- [x] CIPÓ 40 exact mortgage installments through 20/12/2029; TR-dependent tail explicit through 20/06/2052.
- [x] Reconciliation v4: 12 exact, 32 pending, 1 divergent, 1 unresolved, 6 source-only.
- [x] Documentary card coverage: source R$1,465,713.29; same-category R$894,312.01; capped floor R$569,196.83; 19/32 some coverage, 12/32 enough category amount but no promotion. QA 6/6.
- [x] Móveis duplicate R$2,937.26 proven and handled without duplicate economic effect.
- [x] CIPÓ open-blocker QA 6/6 PASS: Consórcio delta R$303.60 remains explicit; arithmetic overlap does not suppress rows; Condomínio formula/cut remains unresolved; no natural raw/dedup monthly cut matches source within R$0.02; duplicate excess through Jul/2026 = R$3,531.70.
- [~] Real user review 30/08: current Patrimônio presentation rejected; rebuild executive-first without changing certified financial semantics.
- [ ] Condomínio formula/cut unresolved. Best tested natural raw-cut gap R$1,780.358; best date+value-dedup cut gap R$1,312.268. Do not rewrite ledger from proximity.
- [ ] Consórcio Itaú R$303.60 delta unresolved. R$6,654.50 = R$6,502.70 + R$151.80 is overlap evidence only; dates differ and no invalid row is identified.
- [ ] Post-2029 TR-dependent values must not be fabricated.
- [~] Volvo provisional until trim/km evidence; net-worth history only with sufficient evidence.

## 8. Semantic classification
- [x] User-confirmed rules priority; unsafe auto-classification blocked.
- [x] Matcher ~2.65s → ~0.314s over 5,224 rows with zero output difference.
- [x] 48 groups / 53 lines / 62 options; safe suggestions 0; 26 effective August lines remain human-review gaps.
- [x] Objective classification triage backend orders review by value/share/repetition only, proposes no category, requires review for every item, is auth.uid-scoped and anon-blocked. QA **9/9 PASS**.
- [~] Integrate triage into a compact review queue; current whitespace-heavy v141 visual is explicitly rejected.
- [~] Real authenticated save→cache→UI click pending.
- [~] Research vendor evidence only where appropriate; propagate only confirmed/history-safe rules.
- [ ] Never classify from appearance/order/screenshot alone.

## 9. Performance / refresh
- [x] Despesas ~29s → ~0.1s; Flow ~4.6s → ~10ms; semantic ~2.65s → ~0.314s; Planning ~9.84s → ~3.96s.
- [x] Operational refresh v3 reuses one annual Flow; warm ~11.8s; stale-expense rollover simulation ~14.06s and rolled back.
- [x] Browser product v9/api39 uses v3; shared-flow parity 6/6 PASS.
- [~] Further optimization only with exact parity; final authenticated latency pending.

## 10. Data quality / gates
- [x] Core 15/15; readiness 51/51; UI shape 17/17; UI consistency 7/7; writer-refresh 9/9; anon browser exposure 0.
- [x] Expense v9 19/19; v10 18/18; Planning 23/23; Wealth 18/18; classification 5/5; lifecycle 17/17; documentary lens 4/4.
- [x] Card coverage v2 8/8; historical registry v4 16/16; global historical fallback inventory 5/5; effective-history v2 PASS; FIX86 v4 10/10.
- [x] Backup 13/13; shared-flow 6/6; CIPÓ coverage 6/6; candidate UI extension 6/6; CIPÓ open blockers 6/6.
- [x] Document outcome semantics 4/4 and browser ACL 4/4; document association 5/5; classification triage 9/9 PASS.
- [x] Extended heavy gate **v12 = 268/268 PASS across 22 suites** before the v142 UX wrapper.
- [~] Candidate parser/browser smoke must be expanded to v142 before v142 can be called green.
- [ ] Authenticated visual E2E outside automated evidence.

## 11. Open Finance
- [x] Provider-neutral private staging + lifecycle writer v2; architecture QA 14/14; no provider account/token/consent/commitment.
- [x] Pluggy remains first sandbox candidate: official current coverage explicitly supports Itaú/Bradesco/C6 Open Finance principal data products; sandbox available pre-sales; production OF connector is premium and price/SLA still needs written commercial terms.
- [x] Belvo remains benchmark: public Launch R$6,000/month and free sandbox; OFDA aggregation explicitly covers Itaú/Bradesco but current aggregation matrix does not list C6. `c6_retail` in payments is not accepted as aggregation proof.
- [x] Klavi remains alternative: sandbox fully simulated; testing/development mirrors production with real consent/data, daily consent limit and no billing; public production price not found.
- [~] Obtain production pricing/support/SLA and explicit product×bank coverage before provider decision.
- [ ] Real provider connection/consent/spend requires explicit user decision.

## 12. Backup / continuity
- [x] Canonical export + safe restore; private daily snapshot with RLS/hash; browser cannot read payload.
- [x] `pg_cron` job daily 06:15 UTC / 03:15 BRT; one snapshot/user/date, idempotent; metadata-only UI status.
- [x] Public fallback/checkpoints recoverable.
- [~] Keep checkpoint files synchronized after material batches.

## 13. Remaining user-dependent decisions
- [ ] Authenticated visual homologation only after the P0 recovery candidate is internally green and the Planning bridge is closed or reduced to a genuine user decision.
- [ ] Human classification where no safe evidence emerges.
- [ ] Any new financial assumption/scenario.
- [ ] Open Finance provider/consent/spend.
- [ ] Volvo refinement with trim/km evidence.

Until one of these is the genuine blocker, continue autonomous technical/documentary work.