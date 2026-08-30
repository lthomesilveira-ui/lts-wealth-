# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

This is the canonical persistent list of project work. Completed-batch evidence remains immutable under `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` and `NEXT_HOMOLOGATION_GATE.md`. Compacting completed history here must never remove an open dependency or unresolved documentary gap.

## 0. Release / homologation
- [x] Public `index.html` remains WIP35-v136 fallback; exact fallback blob is guarded. v136 is not user-approved; effective prior visual baseline is v135.
- [x] WIP35-v137 failed real homologation and must never be promoted.
- [x] v139 real authenticated boot failure was reproduced from user evidence: stuck on `Carregando seu LTS…` because candidate layers treated lexical v136 state as `window.*`; old synthetic-readiness Chromium could false-green this path.
- [x] v140 added an explicit lexical-state bridge without modifying public v136 and removed synthetic D/S readiness from browser smoke.
- [x] User confirmed v140 opened in a real mobile session.
- [x] Current material candidate is `wip35-v141-candidate.html`; latest verified chain head `2bb8f5968cd2bc0ad19ba756d1522307593ccd3c`.
- [x] Chromium candidate smoke run 33282756752 SUCCESS across v141→v140→v139→v138→v137→v136 with real lexical bridge, no synthetic D/S/render payload and zero new browser errors.
- [x] Pages run 33282756246 SUCCESS on the same verified head.
- [x] Public fallback remains unchanged; promotion has not occurred.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] Do not promote candidate to `index.html` before user homologation.
- [ ] Do not ask user for basic QA; next request must be a material visual/authenticated homologation or a real business/financial decision.

## 1. Executive UX / current candidate
- [x] Despesas timeout root cause fixed with exact-parity cache-backed reads.
- [x] Fluxo timeout root cause fixed with exact-parity future cache and authenticated browser Flow v4.
- [x] v140 now installs legacy Flow v1/v2/v3 → Flow v4 routing immediately when lexical `S` is available, removing the first-load race before product `D` finishes.
- [x] Planejamento and Cartões were structurally redesigned as decision cockpits rather than report-like pages.
- [x] v141 Atualizações now prioritizes 6 near/current operational checks, collapses 4 distant 2030/2031 coverage checks and collapses 15 covered/monitoring checks without deleting audit evidence.
- [x] v141 separates the 48 classification groups from the headline operational-action count and suppresses duplicate far-future presentation from v139.
- [x] v141 header/footer identify the candidate coherently and inner old-candidate badges are hidden while stating v136 remains public fallback.
- [~] Visual approval of Fluxo, Despesas, Cartões, Planejamento, Atualizações and Patrimônio remains pending on the latest material candidate.

## 2. Atualizações / maintenance center
- [x] Checklist-first maintenance, direct upload, bank/card/financing/salary/IPVA checks and manual invoice update exist.
- [x] Operational resolutions are append-only; document lifecycle v2 adds evidence-based `O que mudou`.
- [x] Small confirmation writes use targeted refresh rather than global refresh.
- [x] Current 25 maintenance checks are presentation-separated: 6 near actionable, 4 distant actionable coverage, 15 covered/monitoring.
- [~] Prove resolved-item disappearance/reliable refresh in a real authenticated click path.
- [~] Keep primary queue restricted to real decisions; methodology/informational guardrails stay collapsed/contextual.

## 3. Despesas
- [x] Canonical historical total remains R$8,623,752.53 from 10/10/2013; settlement/transfer/asset double counting remains excluded.
- [x] Effective cache closes 3,767/3,767 rows and R$8,623,752.53 exactly.
- [x] Candidate YTD read is ~0.10–0.20s versus ~29.2s old path, with permanent latency guard <1500ms.
- [x] Month/year/rolling comparisons, category rankings/trends and month drilldown exist.
- [x] Documentary range lens keeps structured card merchants separate from cash counterparties; category-only/recovered/aggregate card history never becomes fabricated merchant detail.
- [x] Documentary counterparty QA 4/4 PASS; Expense v9 19/19 PASS; Expense v10 18/18 PASS.
- [~] Real authenticated visual/browser retest remains pending.
- [~] Reduce unclassified/unassigned data only with evidence.
- [ ] Finish CIPÓ historical reconciliation by rubric/year without inference.

## 4. Fluxo Diário
- [x] Flow v12 remains canonical financial truth.
- [x] Future cache preserves range-sensitive `liq_d30`; exact parity previously closed 30/30 days and 13/13 events.
- [x] Browser Flow v4 is authenticated-only; Flow mutations invalidate future cache.
- [x] Current 33-day backend path ~10ms; permanent latency guard <1000ms.
- [x] Initial candidate boot now routes to Flow v4 early through v140 lexical bridge; v139 remains a second routing guard.
- [~] Real authenticated visual/browser retest of the user-observed timeout remains pending.
- [~] Keep saldo/sum rows visually distinct across UI changes.
- [ ] Final authenticated visual E2E.

## 5. Planejamento
- [x] Liquidity order remains cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS ~D+30 contingency.
- [x] Real candidate payload currently supplies 5 liquidity layers and 3 negative episodes.
- [x] Certified semantics remain: first real modeled gap 08/01/2027; worst balance R$-21,046.80; FGTS request-by 09/12/2026 for first gap; v131 12/01 counterfactual preserved.
- [x] Planning executive single-pass ~3.96s with full JSON parity; QA 23/23 PASS.
- [x] Candidate cockpit shows gap/timeline/buffer/FGTS/key drivers/recovery rather than generic cards.
- [~] Visual homologation remains pending.
- [ ] Any new scenario/assumption that changes money requires explicit user decision.

## 6. Cartões / historical validation
- [x] Operating model separates open actual bill from contracted future installments.
- [x] Real candidate payload currently supplies 3 open cycles and 153 monthly historical points.
- [x] 34 historical category-allocation cycles certified exact; 553 allocation rows = R$821,898.39.
- [x] Visa Infinite Itaú 2025: 12/12 certified.
- [x] C6 recovered detail remains separate; Aug/2024 individual-detail gap R$66.70 remains explicit.
- [x] Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- [x] Mastercard Itaú 2024 certified: Mar, May, Aug, Sep, Oct, Dec.
- [x] Dynamic card-history coverage QA 5/5 PASS; 318 aggregate-fallback rows / R$2,714,803.16 remain distinct from certified/recovered detail.
- [~] Mastercard Itaú 2025 Jan/Feb/Jul/Oct remain candidate-only until complete signed composition is recovered.
- [ ] Mastercard Itaú 2025 Sep blocked: matrix R$26,582.10 vs ledger R$26,558.28; credit evidence does not close delta.
- [ ] Mastercard Itaú 2025 Dec blocked: matrix R$14,062.17 vs ledger R$13,195.37; credit evidence does not close delta.
- [~] Mastercard Itaú 2024 pending: Jan evento_base:1829 R$53,652.87; Feb 1871 R$58,667.61; Apr 1966 R$47,802.70; Jun 2061 R$48,393.80; Jul 2104 R$51,947.18; Nov 2281 R$45,259.24.
- [~] File Library remains intermittent for targeted `Cartão Itaú` recovery; technical retrieval failure is not evidence absence.
- [~] Visual homologation of cockpit/coverage lens remains pending.
- [ ] Never certify a historical cycle from total/reference alone; complete signed composition must close to the cent.

## 7. Patrimônio
- [x] Model separates market estimates, documentary debt, equity, liquid/restricted assets and future awards.
- [x] UI contract verifies `wealth_executive.assets` is a named object containing `cipo_396` and `volvo_xc40`; no product change was made to accommodate an initially-wrong QA assumption.
- [x] CIPÓ estimate/debt and Volvo documentary debt remain distinct; Wealth QA 18/18 PASS.
- [~] Visual homologation remains pending.
- [~] Volvo value remains provisional until trim/km evidence is documented.
- [ ] Build net-worth history only when evidence coverage supports it; no unsupported backfill.

## 8. CIPÓ 396 reconciliation
- [x] 40 exact mortgage installments through 20/12/2029; contractual tail remains explicit through 20/06/2052 with TR dependency.
- [x] Current reconciliation v4 remains 12 exact, 32 pending, 1 divergent, 1 unresolved, 6 source-only; QA remains green.
- [x] Source Móveis duplicate R$2,937.26 is proven and excluded from duplicate economic treatment while preserved as evidence.
- [x] Condomínio audit found early exact duplicates, but deduplication does not reproduce source `Pago`; closest tested deduplicated gap still R$1,312.268.
- [x] Consórcio Itaú overlap signal: source R$19,508.10 vs ledger R$19,811.70; delta R$303.60 = 2×R$151.80, but no row is proven invalid.
- [~] Continue rubric-by-rubric reconciliation only when documentary evidence becomes available.
- [ ] Condomínio formula/cut unresolved; do not suppress duplicate-looking rows without full closure.
- [ ] Consórcio Itaú R$303.60 unresolved; mathematical overlap is insufficient for correction.
- [ ] Post-2029 TR-dependent tail must never be treated as zero or fabricated exact values.

## 9. Semantic classification
- [x] User-confirmed rules have priority; unsafe auto-classification is blocked; people names are not researched invasively.
- [x] Matcher optimized ~2.65s → ~0.314s over 5,224 rows with zero output differences.
- [x] Scoped refresh and classification cache QA 5/5 PASS; permanent latency gate currently ~1.45s (<5000ms).
- [x] Current review = 48 groups / 53 lines across August and future September cycles; 62 category options; safe suggestion groups = 0.
- [x] The 26 economically effective August card lines remain genuine human-review gaps unless new evidence changes them.
- [~] Real authenticated save → cache → UI click path remains pending; do not claim it as tested.
- [~] Research merchant/vendor evidence where appropriate and propagate only confirmed/history-safe classifications.
- [~] Resolve taxonomy conflicts without inventing a canonical category.
- [ ] Never infer classification from merchant appearance, visual order or screenshot alone.

## 10. Inputs / documents
- [x] Private upload/storage and direct upload inside Atualizações exist.
- [x] Lifecycle v2 + `document-change-summary-v1` summarizes only actually applied targets; QA 17/17 PASS.
- [x] Documented card purchase remains explicitly separated from bank cash effect before invoice reconciliation.
- [x] Browser product can perform Updates-only same-day schema self-heal; auth→RPC lifecycle path previously passed.
- [~] Real authenticated UI validation of self-heal / `O que mudou` remains pending.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [~] Upload UI should make changed/unchanged/decision-required states explicit.
- [ ] User review should ultimately be limited to exceptions/ambiguities.

## 11. Performance / refresh architecture
- [x] Despesas ~29.2s → ~0.10–0.20s; Flow future ~4.59s → ~10ms; semantic matcher ~2.65s → ~0.314s; Planning ~9.84s → ~3.96s.
- [x] Confirmation writes use targeted refresh; same-day browser product cache avoids global refresh.
- [x] Permanent latency QA: Despesas <1500ms, Flow 33d <1000ms, classification queue <5000ms.
- [x] v140 early Flow v4 routing closes first-load race before v139 installation.
- [~] Global stale/day-rollover refresh remains ~18.8s; optimize only module-by-module with exact parity because Dashboard/Flow/scenario layers mix legacy/current semantics.
- [ ] Do not trade correctness for rare daily-refresh speed; universal invalidation/freshness must be proven before broader cache reuse.
- [~] Final real authenticated browser latency remains pending.

## 12. Data quality / regression gates
- [x] Core financial regression 15/15 PASS after latest v141/v140 changes.
- [x] Candidate fast readiness v5 35/35 PASS.
- [x] New real-payload UI contract QA 17/17 PASS; validates types/shapes consumed by Fluxo, Cartões, Planejamento, Atualizações, Classificação and Patrimônio.
- [x] Universal browser ACL: 48 browser RPCs, anon exposure 0, 39 authenticated exposures as required.
- [x] Expense v9 19/19; Expense v10 18/18; Planning 23/23; Wealth 18/18; classification cache 5/5; lifecycle 17/17; documentary expense lens 4/4; card-history coverage 5/5.
- [x] Chromium run 33282756752 PASS without synthetic readiness; Pages run 33282756246 PASS on same verified head.
- [~] Keep gates updated whenever architecture versions change; never weaken semantics to get green.
- [ ] Real authenticated visual E2E remains outside current automated evidence.

## 13. Historical recovery / evidence gaps
- [x] Canonical effective history: 3,767 rows; 3,449 with recovered category detail; 34 certified category-allocation cycles.
- [x] Remaining aggregate fallback: 318 rows / R$2,714,803.16; does not need to reach zero before visual homologation.
- [~] Retry File Library historical recovery only when retrieval service is healthy; do not repeat wasteful attempts in a short interval.
- [~] Keep `HISTORICAL_RECOVERY_LOG.md` and immutable snapshots synchronized after every material exact-recovery batch.
- [ ] Raw historical cash is never rewritten by analytic recovery; signed credits/reversals remain documentary.

## 14. Open Finance
- [x] Provider-neutral private connection/sync/staging architecture exists; RLS enabled; no browser policies.
- [x] Idempotency protected by user/provider/resource/provider-record key.
- [x] Writer v2 ingests provider `created/updated/deleted` lifecycle; provider deletion is staged evidence and never silently deletes canonical LTS history.
- [x] Synthetic transactional lifecycle proof passed and rolled back completely.
- [x] `lts_open_finance_architecture_qa_v3` PASS 14/14.
- [x] Provider research persisted: Pluggy current first sandbox candidate; Belvo benchmark; Klavi alternative requiring deeper validation.
- [x] No provider account, bank consent, token, credential or commercial commitment has been created.
- [~] Confirm production pricing/support/SLA before any provider choice.
- [ ] Real sandbox/provider connection, bank consent or paid production plan requires explicit user decision.

## 15. UX / executive quality
- [x] Despesas has executive history plus documentary merchant/counterparty coverage.
- [x] Cartões has cockpit + dynamic evidence coverage.
- [x] Planejamento explains first gap, negative episodes, FGTS D+30 and v131 transition.
- [x] Atualizações v141 removes long noisy presentation by prioritizing near actions and collapsing distant/covered checks.
- [x] Candidate version labels no longer visually suggest user is testing v136 when opening the isolated candidate.
- [~] Continue checking empty states, mobile overflow, balance-row emphasis and action hierarchy before next user look.
- [ ] User visual approval remains required before promotion.

## 16. Backups / continuity
- [x] Immutable checkpoint `backups/wip35-v141-readiness-ui-contract-batch11-2026-08-29.json` records the v139 boot incident, v140 lexical fix, v141 package, Pages/Chromium evidence, readiness v5 and core gates.
- [x] `NEXT_HOMOLOGATION_GATE.md` synchronized to v141.
- [x] Public fallback remains recoverable and blob-locked.
- [ ] Future periodic snapshot automation remains open; no manual user save is required now.

## 17. Next execution order
- [~] Finish v141 static/browser evidence after every material UI change and keep Pages SHA aligned.
- [~] Continue autonomous UX robustness and read/write contract checks that do not require user credentials or financial decisions.
- [~] Retry documentary Mastercard recovery only when File Library is healthy.
- [~] Continue CIPÓ evidence reconciliation without inference.
- [ ] Ask user to homologate only when remaining risk is genuinely visual/authenticated behavior.
- [ ] Ask user separately when a real classification, financial assumption, Open Finance provider/consent or commercial decision becomes necessary.
- [ ] Promote to `index.html` only after user homologation and all mandatory gates remain green.
