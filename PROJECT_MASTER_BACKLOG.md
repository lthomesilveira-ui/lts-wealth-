# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

This is the canonical persistent list of project work. Completed-batch evidence remains immutable under `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` and `NEXT_HOMOLOGATION_GATE.md`. Compacting completed history here must never remove an open dependency or unresolved documentary gap.

## 0. Release / homologation
- [x] Public `index.html` remains WIP35-v136 fallback. User visual baseline remains effectively v135; v136 was not separately homologated.
- [x] WIP35-v137 failed real homologation and must never be promoted.
- [x] v138/v139 contain materially redesigned Cartões/Planejamento plus Despesas/Atualizações improvements.
- [x] Latest effective candidate chain: `wip35-v139-candidate.html` on commit `3459b8138a63eba5417a48439da4b46195c4d084`.
- [x] Chromium candidate-smoke run 33276722702 SUCCESS: chain v139→v138→v137→v136 correct, v137/v138/v139 injection stamps present, zero browser errors/new errors.
- [x] Browser smoke uses neutral synthetic readiness only after clean boot; it is explicitly not authenticated visual E2E.
- [x] Auth→RPC transactional checks pass for Despesas executive, documentary counterparty lens, card-history coverage, Flow v4, document lifecycle v2 and product cache v36; this is not visual E2E.
- [x] Public fallback v136 blob guard remained unchanged through Chromium fixes.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] Do not ask user for basic QA; next user look only after maximum available checks are exhausted.
- [ ] Do not promote candidate to `index.html` before user homologation.

## 1. Real homologation feedback / executive UX
- [x] Despesas timeout root cause fixed with exact-parity cache read.
- [x] Fluxo timeout root cause fixed in candidate with exact-parity future read cache.
- [x] Classification v35→v36 stale-cache bug fixed; scoped refresh + permanent QA added.
- [x] Rejected report-like Planejamento/Cartões layouts were structurally redesigned as candidate cockpits.
- [x] Atualizações now shows 6 near actions, 4 far-future coverage items collapsed, and 2 informational items collapsed as context.
- [x] Workflow line is compact: Recebido › Interpretado › Reconciliado › Decisão necessária › Resolvido.
- [x] Classification shows real confidence/history evidence and all 62 category choices; current 48 groups = 9 evidence-backed suggestions, 0 safe auto-applications.
- [x] Chromium found premature render defects in v137/v138; both are now guarded until inner payload readiness.
- [~] Visual approval of Despesas, Cartões, Planejamento, Atualizações and Patrimônio remains pending; user has not tested the latest material candidate.

## 2. Atualizações / maintenance center
- [x] Checklist-first maintenance, direct upload, bank/card/financing/salary/IPVA checks and manual invoice update exist.
- [x] Operational resolutions are append-only; document lifecycle v2 adds evidence-based `O que mudou`.
- [x] Small confirmation writes use targeted refresh; no small write remains tied to global refresh.
- [~] Prove resolved-item disappearance/reliable refresh in real authenticated click path.
- [~] Continue ensuring primary queue contains real decisions, not methodology/informational noise.

## 3. Despesas
- [x] Canonical historical total remains R$8,623,752.53 from 10/10/2013; settlement/transfer/asset double counting remains excluded.
- [x] Effective cache closes 3,767/3,767 rows and R$8,623,752.53 exactly.
- [x] Candidate executive read ~0.20s versus ~29.2s prior path, with key-total parity.
- [x] Month/year/rolling comparisons, category rankings/trends and month drilldown exist.
- [x] Documentary range lens is implemented: structured card merchants and cash counterparties are separate; category-only/recovered/aggregate card history never becomes fabricated merchant detail.
- [x] Documentary counterparty QA current contract PASS 4/4.
- [x] Expense v9 rerun after Chromium/readiness changes: 19/19 PASS.
- [x] Expense v10 rerun after Chromium/readiness changes: 18/18 PASS.
- [~] Real authenticated visual/browser retest of Despesas remains pending even though auth→RPC path passes.
- [~] Reduce remaining unclassified/unassigned data only with evidence. Current 26 economically effective August card lines are genuine human-review gaps.
- [~] Continue exact historical card recovery where documents exist.
- [ ] Finish CIPÓ historical reconciliation by rubric/year without inference.

## 4. Fluxo Diário
- [x] Flow v12 remains canonical financial truth.
- [x] Future cache slice preserves range-sensitive `liq_d30`; 30/30 days and 13/13 events matched v12; 33-day backend read ~13ms versus ~4.59s direct.
- [x] Browser Flow v4 auth-only; Flow mutator invalidates future cache.
- [x] Auth→RPC Flow v4 test under simulated authenticated JWT returned successfully.
- [x] Chromium candidate boot now completes with zero browser errors/new errors before synthetic readiness.
- [~] Real authenticated visual/browser retest of the user-observed timeout remains pending.
- [~] Keep balance/sum rows visually distinct across further UI changes.
- [ ] Final authenticated visual E2E.

## 5. Planejamento
- [x] Liquidity order remains cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS ~D+30 contingency.
- [x] Certified semantics remain: first modeled gap 08/01/2027, worst gap R$-21,046.80, three negative episodes, v131 counterfactual preserved.
- [x] Planning executive single-pass ~9.84s → ~3.96s with full JSON parity; QA 23/23 PASS.
- [x] Candidate cockpit shows gap/timeline/buffer/FGTS/key drivers/recovery rather than generic report cards.
- [~] Visual homologation remains pending.
- [ ] Any new scenario/assumption that changes money requires explicit user decision.

## 6. Cartões / historical validation
- [x] Operating invoice model separates open actual bill from contracted future installments.
- [x] 34 historical category-allocation cycles certified exact; 553 allocation rows = R$821,898.39.
- [x] Visa Infinite Itaú 2025: 12/12 certified.
- [x] C6 recovered detail: 347 rows / R$58,727.98; Aug/2024 individual-detail gap R$66.70 remains explicitly open.
- [x] Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- [x] Mastercard Itaú 2024 certified: Mar, May, Aug, Sep, Oct, Dec.
- [x] Dynamic card-history coverage lens + QA 5/5 implemented in candidate; 318 aggregate-fallback rows / R$2,714,803.16 remain visibly distinct from certified/recovered detail.
- [~] Mastercard Itaú 2025 Jan/Feb/Jul/Oct remain candidate-only until complete signed composition is recovered.
- [ ] Mastercard Itaú 2025 Sep blocked: matrix R$26,582.10 vs ledger R$26,558.28; credit evidence does not close delta.
- [ ] Mastercard Itaú 2025 Dec blocked: matrix R$14,062.17 vs ledger R$13,195.37; credit evidence does not close delta.
- [~] Mastercard Itaú 2024 pending: Jan `evento_base:1829` R$53,652.87; Feb `1871` R$58,667.61; Apr `1966` R$47,802.70; Jun `2061` R$48,393.80; Jul `2104` R$51,947.18; Nov `2281` R$45,259.24.
- [~] File Library briefly returned the workbook again, but targeted recovery on the `Cartão Itaú` sheet then failed technically; this is not evidence absence and authorizes no inference.
- [~] Continue per-card history/evolution, future installments and merchant/category drilldown only where evidence supports it.
- [~] Visual homologation of latest cockpit/coverage lens remains pending.
- [ ] Never certify a historical cycle from total/reference alone; complete signed composition must close to the cent.

## 7. Patrimônio
- [x] Model separates market estimates, documentary debt, equity, liquid/restricted assets and future awards.
- [x] Current certified model keeps CIPÓ estimate/debt and Volvo documentary debt distinct; wealth QA 18/18 PASS.
- [~] Visual homologation remains pending.
- [~] Volvo value remains provisional until trim/km evidence is documented.
- [ ] Build net-worth history only when evidence coverage supports it; no unsupported backfill.

## 8. CIPÓ 396 reconciliation
- [x] 40 exact mortgage installments through 20/12/2029; contractual tail remains explicit through 20/06/2052 with TR dependency.
- [x] Current reconciliation v4: 12 exact, 32 pending, 1 divergent, 1 unresolved, 6 source-only; QA remains green.
- [x] Source Móveis duplicate R$2,937.26 is proven and excluded from duplicate economic treatment while preserved as source evidence.
- [x] Condomínio audit found exact early duplicate rows, but deduplication does not reproduce source `Pago` R$115,867.108; closest tested deduplicated cumulative still differs R$1,312.268.
- [x] Consórcio Itaú raw composition exposes overlap signal: source R$19,508.10 vs ledger R$19,811.70; delta R$303.60 = 2×R$151.80, but no row is proven invalid.
- [~] Continue rubric-by-rubric reconciliation when documentary evidence becomes available.
- [ ] Condomínio formula/cut remains unresolved; do not suppress duplicate-looking raw rows without full closure.
- [ ] Consórcio Itaú R$303.60 remains unresolved; mathematical overlap is not sufficient for correction.
- [ ] Post-2029 TR-dependent tail must never be treated as zero or fabricated exact values.

## 9. Semantic classification
- [x] User-confirmed rules have priority; unsafe auto-classification is blocked; people names are not researched invasively.
- [x] Matcher optimized ~2.65s → ~0.314s over 5,224 rows with zero output differences.
- [x] Scoped save refresh: card-only ~0.66s; semantic-only ~1.75s; cache consistency QA 5/5 PASS.
- [x] Latest classification refresh benchmark ~1.60s, payload remains v36, followed by cache consistency 5/5 PASS.
- [x] 26 economically effective unclassified card lines were checked against exact normalized history and active rules; no safe automatic rule exists.
- [~] Real authenticated save → cache → UI click path remains pending.
- [~] Research merchant/vendor evidence where appropriate; propagate only confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without inventing a canonical category.
- [ ] Never infer classification from merchant appearance, visual order or screenshot alone.

## 10. Inputs / documents
- [x] Private upload/storage and direct upload inside Atualizações exist.
- [x] Lifecycle v2 + `document-change-summary-v1` summarizes only actually applied targets; QA 17/17 PASS.
- [x] Documented card purchase is explicitly separated from bank cash effect before invoice reconciliation.
- [x] Browser product can perform Updates-only same-day schema self-heal; auth→RPC lifecycle v2 path passes.
- [~] Real authenticated UI validation of self-heal / `O que mudou` remains pending.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [~] Future upload UI should make changed/unchanged/decision-required states explicit.
- [ ] User review should ultimately be limited to exceptions/ambiguities.

## 11. Performance / refresh architecture
- [x] Despesas ~29.2s → ~0.20s; Flow future ~4.59s → ~13ms; semantic matcher ~2.65s → ~0.314s; Planning ~9.84s → ~3.96s.
- [x] Confirmation writes ~18.8s → ~2.93s; manual invoice update uses targeted financial refresh.
- [x] Same-day browser product cache hit avoids global refresh.
- [x] Permanent latency QA v1 added: Despesas cache <1500ms, Flow 33d <1000ms, classification queue <5000ms.
- [x] Candidate fast readiness v4 combines materialized freshness + universal browser ACL + latency; latest run 18/18 PASS in ~1.59s total.
- [~] Global stale/day-rollover refresh remains ~18.8s. Dashboard/Flow/scenario layers still have duplicated computation; optimize only with full parity because current chain mixes legacy/current semantics.
- [ ] Do not trade correctness for a faster daily refresh; universal invalidation/freshness must be proven before using cached Flow inside all internal planning/dashboard paths.
- [~] Final real authenticated browser latency remains pending.

## 12. Data quality / regression gates
- [x] Expense v9 19/19 PASS; Expense v10 18/18 PASS; core financial regression 15/15 PASS after latest Chromium/readiness fixes.
- [x] Candidate fast readiness v4 18/18 PASS; includes latency QA 3/3 and universal ACL for 48 browser RPCs; anon exposure = 0.
- [x] Planning 23/23 PASS; Wealth 18/18 PASS; expense cache exact; classification cache 5/5; lifecycle 17/17; Flow cache PASS.
- [x] Documentary expense lens QA 4/4; card-history coverage QA 5/5.
- [x] Chromium candidate smoke run 33276722702 PASS: chain/injections green, zero errors.
- [x] Auth→RPC layer successfully exercised transactionally for current browser surfaces; checkpoint explicitly says this is not visual E2E.
- [~] Keep gates updated when architecture versions change; never weaken semantics to make a gate green.

## 13. Historical recovery / evidence gaps
- [x] Canonical effective history: 3,767 rows; 3,449 with recovered category detail; 34 certified category-allocation cycles.
- [x] Remaining aggregate fallback: 318 rows / R$2,714,803.16; does not need to reach zero before visual homologation.
- [~] File Library service remains intermittently unavailable for targeted Mastercard recovery.
- [~] Retry only when retrieval service becomes available; continue other work meanwhile.
- [~] Keep `HISTORICAL_RECOVERY_LOG.md` and immutable snapshots synchronized after every material exact-recovery batch.
- [ ] Raw historical cash is never rewritten by analytic recovery; signed credits/reversals must remain documentary.

## 14. Open Finance
- [x] Provider-neutral private staging exists with connection, sync-run and staging tables; RLS is enabled and browser has no direct policies.
- [x] Staging unique key protects idempotency by user/provider/resource/provider-record-id.
- [x] External lifecycle fields exist for provider `created/updated/deleted` behavior; provider deletion is staged evidence and never silently deletes canonical LTS history.
- [x] `lts_open_finance_stage_record_v2` now ingests `source_event_type`, `provider_updated_at` and `provider_deleted_at`; writer is service-role-only.
- [x] Synthetic transactional lifecycle proof passed and rolled back completely: one idempotent staging identity survived create/snapshot/update/delete sequence inside the transaction; update changed staged amount/hash; delete stayed `promotion_status=pending` and only set deletion evidence.
- [x] `lts_open_finance_architecture_qa_v3` PASS 14/14.
- [x] Provider research persisted in `OPEN_FINANCE_PROVIDER_RESEARCH_2026-08-29.md`: Pluggy is current first sandbox candidate; Belvo benchmark; Klavi alternative requiring deeper institution-level validation.
- [x] Official current evidence shows Pluggy supports Itaú, Bradesco and C6 accounts/transactions/credit cards and documents bank-specific installment inconsistency; LTS must normalize/reconcile rather than blindly trust installment metadata.
- [x] No provider account, bank consent, token, credential or commercial commitment has been created.
- [~] Remaining sandbox step requires a real provider sandbox account/token or equivalent external credential; do not create/connect without user decision if terms/consent/commercial commitment are involved.
- [~] Confirm production pricing/support/SLA before any provider choice.
- [ ] Real provider connection, consent or paid production plan requires explicit user decision before execution.

## 15. UX / executive quality
- [x] Despesas candidate has executive history plus documentary range-level counterparty/merchant coverage.
- [x] Cartões candidate has cockpit + dynamic historical evidence coverage rather than a manual certification list.
- [x] Planejamento candidate answers first-gap/buffer/resource questions rather than presenting a generic report.
- [x] Atualizações prioritizes near actions and collapses future/context/methodology.
- [~] Continue replacing explanatory-only blocks with evidence-backed interaction; keep secondary history/methodology from overwhelming the first fold.
- [~] Make empty/decision states actionable and eliminate passive blank areas.
- [~] Desktop/mobile consistency remains pending real authenticated visual verification.
- [ ] Never call a report-like page a cockpit merely because it has KPI cards.

## 16. Backup / continuity
- [x] `PROJECT_MASTER_BACKLOG.md` is canonical; historical/release evidence also remains in `HISTORICAL_RECOVERY_LOG.md`, homologation incident log and `NEXT_HOMOLOGATION_GATE.md`.
- [x] Latest immutable checkpoints include batch 9 `backups/wip35-v139-browser-smoke-batch9-2026-08-29.json` and batch 10 `backups/wip35-v139-readiness-open-finance-batch10-2026-08-29.json`.
- [x] No user manual save is currently required.
- [ ] Add automated periodic repository/data snapshot only after proving credentials/private documents cannot leak into artifacts or logs.
