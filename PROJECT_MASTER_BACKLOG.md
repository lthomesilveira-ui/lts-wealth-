# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Completed evidence remains under `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` and `NEXT_HOMOLOGATION_GATE.md`. Never remove an open financial/documentary dependency during compaction.

## 0. Release / homologation
- [x] Public `index.html` remains WIP35-v136 fallback; exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` is guarded. v136 is not user-approved; effective prior visual baseline is v135.
- [x] v137 failed real homologation; v139 failed real authenticated boot because lexical v136 state was incorrectly treated as `window.*`.
- [x] v140 added lexical bridge, removed synthetic D/S/render readiness, installed early Flow-v4 routing; user confirmed v140 opened in real mobile session.
- [x] Current material candidate remains `wip35-v141-candidate.html`.
- [x] v141 version-ownership bug fixed: v140 can no longer overwrite visible v141 label.
- [x] Latest candidate code/smoke head `5d67b2e2d719c309d9159e078d3c2e681e6ab361`; candidate-smoke run `33311276232` SUCCESS.
- [x] Chromium desktop/mobile requires real lexical bridge, Flow-v4 runtime bridge, visible v141 label, current CIPÓ/backup/shared-flow extension stamp, zero new errors and no root overflow.
- [x] GitHub Pages build/deploy checks on the same `5d67b2e2…` head are SUCCESS (`deploy` check 99256687084; Pages run 33311275717).
- [x] Public fallback remains unchanged; no promotion occurred.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] Promotion to `index.html` only after user homologation.
- [ ] Do not ask user for basic QA; next request must be material authenticated visual homologation or a genuine user decision.

## 1. Executive UX / candidate
- [x] Despesas timeout fixed with exact-parity cache-backed reads.
- [x] Fluxo timeout fixed with cache-backed authenticated Flow v4; initial boot race closed by v140 early bridge.
- [x] Planejamento and Cartões are decision cockpits rather than report-like pages.
- [x] Atualizações v141 shows 6 near/current operational actions first, collapses 4 distant coverage checks and 15 covered/monitoring checks, and separates 48 classification groups from operational count.
- [x] v141 header/footer identify the candidate coherently; inherited candidate badges are hidden.
- [x] Patrimônio candidate has non-promoting CIPÓ documentary-progress block.
- [x] Configurações candidate has metadata-only automatic-backup status; private snapshot payload is never exposed.
- [~] Visual approval of Fluxo, Despesas, Cartões, Planejamento, Atualizações, Patrimônio and Configurações remains pending.
- [~] Continue checking mobile overflow, empty states, balance-row emphasis and action hierarchy before user look.

## 2. Atualizações / maintenance center
- [x] Checklist-first maintenance, direct upload, bank/card/financing/salary/IPVA checks and manual invoice update exist.
- [x] Operational resolutions are append-only; document lifecycle v2 provides evidence-based `O que mudou`.
- [x] Writers use scoped refresh; writer→refresh/safety QA 9/9 PASS.
- [x] 25 checks presentation-separated: 6 near actionable, 4 distant coverage, 15 covered/monitoring.
- [~] Real authenticated resolved-item disappearance/save-refresh click path remains pending/unclaimed.
- [~] Keep informational/methodology guardrails contextual and outside primary action count.

## 3. Despesas
- [x] Historical total R$8,623,752.53 from 10/10/2013 remains invariant; 3,767/3,767 effective rows exact.
- [x] YTD cache read ~0.1s versus ~29s old path; permanent <1500ms latency guard.
- [x] Month/year/rolling comparisons, rankings/trends, drilldown and documentary merchant/counterparty lens exist.
- [x] Merchant lens uses structured purchase evidence only; recovered/category/aggregate history never fabricates merchants.
- [x] Expense v9 19/19; Expense v10 18/18; documentary counterparty QA 4/4 PASS.
- [x] Daily rollover now refreshes expense cache when stale; it can no longer remain one day behind product/Flow.
- [~] Real authenticated visual retest pending.
- [~] Reduce unclassified/unassigned only with evidence.

## 4. Fluxo Diário
- [x] Flow v12 remains canonical financial truth.
- [x] Future cache preserves range-sensitive `liq_d30`; cached 33d path ~10ms with <1000ms guard.
- [x] Flow mutations invalidate future cache; browser Flow v4 authenticated-only.
- [x] v140 routes old Flow browser RPCs to v4 immediately after lexical `S` exists; runtime Chromium proves bridge installation.
- [x] Shared-Flow architecture proves 43-day slice JSON/MD5 identical to direct Flow v12.
- [~] Keep saldo/sum rows visually distinct across UI changes.
- [ ] Final authenticated visual E2E.

## 5. Planejamento
- [x] Liquidity order: cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS ~D+30 contingency.
- [x] Current payload: 5 layers, 3 negative episodes; first real gap 08/01/2027; worst balance R$-21,046.80; FGTS request-by 09/12/2026; v131 12/01 counterfactual preserved.
- [x] Planning QA 23/23 PASS.
- [x] Shared annual Flow feeds Planning with JSON/MD5 exact parity to prior motor.
- [~] Visual homologation of rationale/cockpit pending.
- [ ] Any new assumption/scenario changing money requires explicit user decision.

## 6. Cartões / historical validation
- [x] Open bill remains separate from future installments; current payload has 3 open cycles and 153 historical months.
- [x] 34 exact historical category-allocation cycles; 553 rows / R$821,898.39.
- [x] Visa Infinite Itaú 2025 = 12/12 exact.
- [x] Mastercard Itaú 2025 certified Mar/Apr/May/Jun/Aug/Nov.
- [x] Mastercard Itaú 2024 certified Mar/May/Aug/Sep/Oct/Dec.
- [x] C6 Aug/2024 category total certified; individual-detail gap R$66.70 remains explicit.
- [x] Card-history coverage QA 5/5 PASS; 318 aggregate fallback rows / R$2,714,803.16 remain distinct.
- [x] Internal `lts_card_historical_validation_registry` persists all 12 open Mastercard 2024/2025 cycles; QA 7/7 PASS and browser access blocked.
- [~] 2025 Jan/Feb/Jul/Oct are candidate-partial only; full signed category tails required.
- [ ] 2025 Sep blocked: source R$26,582.10 vs ledger R$26,558.28; known credit does not close R$23.82 delta.
- [ ] 2025 Dec blocked: source R$14,062.17 vs ledger R$13,195.37; known credit does not close R$866.80 delta.
- [~] 2024 Jan/Feb/Apr/Jun/Jul/Nov have exact payment identity but no recovered complete category composition; never certify from total/reference alone.
- [~] File Library retrieval remains intermittent; latest targeted Jan/Feb/Jul/Oct search failed before returning content. Retrieval failure != evidence absence.
- [~] Continue older-year recovery only with documentary evidence and independent signed closure.
- [~] Visual homologation of cockpit/evidence coverage pending.

## 7. Patrimônio
- [x] Market estimate, documentary debt, equity, liquid/restricted assets and future awards remain separate.
- [x] `wealth_executive.assets` named-object contract with `cipo_396` and `volvo_xc40` is gated; Wealth QA 18/18 PASS.
- [x] `wealth.cipo_396.card_documentary_coverage` adds evidence progress without affecting valuation/debt/equity.
- [~] Visual homologation pending.
- [~] Volvo value remains provisional until trim/km evidence is documented.
- [ ] Build net-worth history only when evidence coverage supports it; no unsupported backfill.

## 8. CIPÓ 396 reconciliation
- [x] 40 exact mortgage installments through 20/12/2029; TR-dependent contractual tail remains explicit through 20/06/2052.
- [x] Reconciliation v4: 12 exact, 32 pending, 1 divergent, 1 unresolved, 6 source-only.
- [x] Source Móveis duplicate R$2,937.26 proven and excluded from duplicate economic treatment while retained as evidence.
- [x] Documentary card-coverage lens: source aggregates R$1,465,713.29; same-category observed R$894,312.01; conservative capped evidence floor R$569,196.83; 19/32 with some evidence, 12/32 with enough category amount but still not promoted without instrument identity. QA 6/6 PASS.
- [ ] Condomínio formula/cut unresolved; duplicate-looking rows cannot be suppressed without full closure.
- [ ] Consórcio Itaú source R$19,508.10 vs ledger R$19,811.70; R$303.60 delta/overlap signal remains unresolved.
- [ ] Post-2029 TR-dependent tail must never be treated as zero or fabricated exact.
- [~] Continue rubric-by-rubric reconciliation when documentary evidence becomes available.

## 9. Semantic classification
- [x] User-confirmed rules have priority; unsafe auto-classification blocked.
- [x] Matcher optimized ~2.65s → ~0.314s over 5,224 rows with zero output difference.
- [x] Current review 48 groups / 53 lines, 62 options, safe suggestion groups = 0.
- [x] 26 economically effective August card lines remain genuine human-review gaps.
- [~] Real authenticated save→cache→UI click path remains pending/unclaimed.
- [~] Research merchant/vendor evidence only where appropriate; propagate only confirmed/history-safe rules.
- [ ] Never classify from merchant appearance, visual order or screenshot alone.

## 10. Inputs / documents
- [x] Private upload/storage and direct upload inside Atualizações exist.
- [x] Lifecycle v2 + `document-change-summary-v1`; QA 17/17 PASS.
- [x] Documented card purchase stays separated from bank cash effect until invoice reconciliation.
- [~] Real authenticated UI validation of self-heal / `O que mudou` remains pending.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [~] Upload UI should make changed/unchanged/decision-required states explicit.
- [ ] User review should ultimately be exception-only.

## 11. Performance / refresh architecture
- [x] Despesas ~29s → ~0.1s; Flow future ~4.6s → ~10ms; semantic matcher ~2.65s → ~0.314s; Planning prior ~9.84s → ~3.96s.
- [x] Same-day product cache avoids global refresh; confirmation writes use targeted refresh.
- [x] Operational refresh v3 calculates one annual Flow v12 and reuses it for short Flow, Planning, Dashboard and cashflow scenarios.
- [x] Planning, Dashboard, short Flow and scenarios each proved JSON + MD5 exact against prior motors.
- [x] Warm daily refresh ~20.2s → ~11.8s; stale-expense rollover simulation ~14.06s including ~2.82s expense-cache rebuild; simulation rolled back.
- [x] Browser product RPC v9/api 39 uses operational v3 on day rollover.
- [x] Shared-flow parity QA 6/6 PASS.
- [~] Profile further only with exact parity; do not trade correctness for speed.
- [~] Final real authenticated browser latency pending.

## 12. Data quality / regression gates
- [x] Core financial regression 15/15 PASS.
- [x] Readiness v7 51/51 PASS; UI shape 17/17; UI consistency 7/7; writer-refresh 9/9.
- [x] Universal browser ACL: 48 browser RPCs, anon exposure 0, 39 authenticated exposures.
- [x] Candidate UI extension QA 6/6 PASS.
- [x] Shared-flow parity 6/6; backup snapshot QA 13/13; CIPÓ coverage 6/6; historical validation registry 7/7.
- [x] Extended heavy pre-homologation gate v3 = **213/213 PASS** across 15 suites.
- [x] Candidate smoke run 33311276232 and Pages deploy on the same `5d67b2e2…` head are SUCCESS.
- [~] Keep gates strengthened whenever architecture evolves; never weaken semantics for green.
- [ ] Real authenticated visual E2E remains outside automated evidence.

## 13. Historical recovery / evidence gaps
- [x] Canonical history: 3,767 effective rows; 3,449 recovered category-detail rows; 34 certified allocation cycles.
- [x] Persistent `HISTORICAL_RECOVERY_LOG.md` updated through 30/08 validation-registry batch.
- [x] Six pending Mastercard 2024 months explicitly classified as settlement-proven/composition-missing.
- [x] Four candidate and two blocked Mastercard 2025 months persist in internal evidence registry.
- [~] Retry File Library only when retrieval service is healthy; do not repeatedly hammer failed retrieval.
- [~] After any exact recovery, rerun card-history/expense/core/heavy gates and persist immutable evidence.
- [ ] Raw historical cash is never rewritten by analytical recovery.

## 14. Open Finance
- [x] Provider-neutral private staging architecture + lifecycle writer v2, RLS/no browser policies, idempotency and rolled-back synthetic proof exist; architecture QA 14/14 PASS.
- [x] Pluggy remains first sandbox candidate; Belvo benchmark; Klavi alternative. Public research distinguishes known price/sandbox facts from sales-only terms.
- [x] No provider account, bank consent, token, credential or commercial commitment created.
- [~] Confirm production pricing/support/SLA/product×bank coverage before provider decision.
- [ ] Real sandbox/provider connection, consent or spend requires explicit user decision.

## 15. Backup / continuity
- [x] Canonical backup export + safe restore already exist.
- [x] Private daily snapshot table created with RLS, hash and deterministic serialized byte count; browser roles cannot read/create snapshots.
- [x] `pg_cron` enabled; job `lts_daily_backup_snapshot` active daily at 06:15 UTC / 03:15 BRT.
- [x] One snapshot per user/date; duplicate same-day invocation is idempotent.
- [x] Backup snapshot QA 13/13 PASS; authenticated UI receives metadata only via `lts_browser_backup_status_v1`.
- [x] Public fallback and immutable repo checkpoints remain recoverable.
- [~] Keep checkpoint files synchronized after material batches.

## 16. Remaining user-dependent decisions
- [ ] Authenticated visual homologation of current v141 package when user has time.
- [ ] Human classification decisions for unresolved card lines unless new evidence makes a safe suggestion possible.
- [ ] Any financial assumption/scenario change.
- [ ] Open Finance provider/consent/spend decision.
- [ ] Volvo valuation refinement if trim/km evidence is supplied.

Until one of these is the genuine blocker, continue autonomous technical/documentary work.
