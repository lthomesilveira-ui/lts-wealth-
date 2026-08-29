# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

This is the canonical persistent list of project work. Detailed evidence for completed batches is preserved in the immutable files under `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` and `NEXT_HOMOLOGATION_GATE.md`. Compacting completed history here must never remove an open dependency or unresolved documentary gap.

## 0. Release / homologation state
- [x] WIP35-v136 remains the public canonical fallback at `index.html`; it has not been visually homologated by the user as a replacement for the v135 visual baseline.
- [x] WIP35-v137 failed real user homologation on 2026-08-29: Despesas timeout plus Planejamento/Cartões visual rejection; it must never be promoted.
- [x] WIP35-v138 introduced materially redesigned Cartões/Planejamento cockpits plus Despesas/Atualizações improvements while preserving v136 fallback.
- [x] WIP35-v139 is served only as isolated candidate `wip35-v139-candidate.html`; public `index.html` remains untouched.
- [x] Latest v139 UI commit `d374eb152fff0cbb9644a674ae28527681a75f21` was published successfully by GitHub Pages run 33273116737.
- [x] Permanent read-only candidate CI created in `.github/workflows/candidate-smoke.yml` + `.github/scripts/lts_candidate_smoke.py`; it has contents-read permission only, does not modify `index.html`, does not commit shells and does not trigger candidate promotion.
- [x] Candidate CI run 33273277469 SUCCESS. Artifact 9720729260 confirms one inline script, `node_check_0=0`, all required v139/Flow/Updates/document-summary guardrails present and all forbidden direct write/index markers absent.
- [x] Exact CI evidence persisted at `backups/wip35-v139-candidate-smoke-ci-2026-08-29.txt`, commit `e1f2221b...`.
- [ ] Real authenticated visual E2E remains pending and must not be claimed before it is actually performed.
- [ ] Do not ask the user to homologate again until maximum available authenticated/browser checks are exhausted and all financial/data gates remain green.
- [ ] Do not promote any candidate to `index.html` before user homologation.

## 1. Real homologation feedback V135 → V137/V139
- [x] CRITICAL ROOT CAUSE — Despesas `canceling statement due to statement timeout` diagnosed and backend read path replaced by exact-parity cache-backed read.
- [x] CRITICAL ROOT CAUSE — Fluxo Diário timeout diagnosed and future read path replaced in candidate by exact-parity future cache slice.
- [x] CRITICAL ROOT CAUSE — Classificação save/refresh v35→v36 mismatch corrected; scoped refresh + permanent live/cache QA added.
- [x] Planejamento v136/v137 report-like UI rejected; materially new cockpit implemented in v138/v139 candidate.
- [x] Cartões v136/v137 report-like UI rejected; materially new cockpit implemented in v138/v139 candidate.
- [x] Atualizações direction was positively received; v139 further reduces density by showing only 10 actionable items in the main queue and moving 2 informational/guardrail items into collapsed `Contexto / monitoramento`.
- [x] Atualizações lifecycle visual compacted to one line: Recebido › Interpretado › Reconciliado › Decisão necessária › Resolvido.
- [x] Atualizações classification UI restores direct confidence % only when backed by a real score/evidence and exposes history/evidence signal without fabricating confidence.
- [x] All 48 current card-classification groups have the full 62 category options; 9 have evidence-backed suggestions and 39 explicitly remain without a safe suggestion.
- [~] Visual approval of Cartões, Planejamento, Atualizações, Patrimônio and Despesas remains pending because the user’s effective visual baseline is v135.

## 2. Atualizações / Central de manutenção
- [x] Checklist-first layout, reduced dead space, direct upload, ledger check, statements/card bill/financing/salary/IPVA checks and manual bill update exist.
- [x] Document lifecycle is persisted; operational resolutions are append-only in `lts_update_lifecycle_event` and resolution is logged before removal from the active cache.
- [x] Operational lifecycle transactional QA passed with zero QA residue after rollback.
- [x] v139 main queue = 10 actionable items; `own_transfer_unpaired` and `aeternum_estimator` remain visible only as collapsed informational context, not falsely marked resolved.
- [x] Classification first reading prioritizes action/confidence/history/decision; detailed rationale remains collapsible.
- [x] Small confirmation writes use targeted refresh rather than rebuilding the entire product.
- [~] Resolved items must be proven to disappear immediately/reliably in the real authenticated click path; backend patch/lifecycle are implemented, but browser click-path E2E is still pending.
- [~] Continue removing non-actionable informational density as new maintenance checks are added; active queue should represent real user decisions, not methodology.

## 3. Despesas
- [x] Effective-spend semantics exclude duplicate card settlement, own transfers and non-expense asset movements.
- [x] History available from 10/10/2013 with historical total invariant at R$ 8,623,752.53.
- [x] Month/year/full-history/rolling 3/6/12M/partial-period comparisons/rankings/trends/month drilldown exist.
- [x] Certified historical card category allocation replaces technical aggregate fallback only where cycle closes exactly; no merchant/purchase fabrication.
- [x] `lts_expense_effective_read_cache` is derived from canonical effective rows and currently closes 3,767/3,767 rows, R$ 8,623,752.53 on both sides, 0 missing/extra/mismatch.
- [x] Candidate browser read uses `lts_browser_expense_executive_v4`; benchmark ~0.20s versus ~29.2s old path with zero delta on key totals.
- [x] Category ranking/12M trends in candidate are interactive and monthly detail delegates to certified month-detail logic.
- [~] Real authenticated browser load must still be retested before marking the user-observed Despesas timeout fully closed.
- [~] Extend merchant-level drilldown across the whole selected range where documentary merchant evidence exists, not only via monthly category focus.
- [~] Continue reducing unclassified/unassigned history without changing total economics.
- [~] Continue historical card cycle recovery only with exact documentary closure.
- [ ] Complete CIPÓ historical reconciliation by rubric/year against source evidence without inference.

## 4. Fluxo Diário
- [x] Flow v12 remains canonical financial truth for the current operational/planning model.
- [x] Future cache architecture `lts_flow_future_read_cache` + `lts_flow_future_read_slice_v2` preserves range-sensitive `liq_d30` and exact day/event parity.
- [x] Current QA: 30/30 days and 13/13 events equal to v12; 33-day backend benchmark ~13ms versus ~4.59s direct v12.
- [x] Candidate uses authenticated-only `lts_browser_flow_v4`; anon execution is blocked.
- [x] Flow mutator invalidates future cache so edits cannot silently serve stale future values.
- [x] Naive first cache implementation that altered `liq_d30` was rejected before integration.
- [~] Real authenticated browser retest remains pending before closing the user-observed Fluxo timeout incident.
- [~] Maintain visually distinct balance/sum rows (saldo anterior, saldo final, disponível total etc.) across future UI changes.
- [ ] Final authenticated visual E2E for Flow.

## 5. Planejamento
- [x] Liquidity ladder remains cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS D+30.
- [x] First real modeled gap remains 08/01/2027; worst current gap remains R$ -21,046.80; three negative episodes remain documented.
- [x] v131 12/01/2027 baseline is preserved by counterfactual: without Volvo first gap 10/01; without Volvo + IPVA returns to 12/01.
- [x] FGTS remains restricted emergency contingency with ~30-day lead time; request-by date for first gap 09/12/2026; it does not automatically enter cash.
- [x] Planning executive was rewritten single-pass live: ~9.84s → ~3.96s, full JSON equal to prior implementation.
- [x] Planning QA remains 23/23 PASS after optimization.
- [x] Candidate cockpit presents first gap, worst point/buffer, FGTS D+30, liquidity timeline, episodes, key outflows, recoveries and compact v131 transition.
- [~] Visual redesign remains pending real user homologation; do not mark cockpit approved from static checks alone.
- [ ] Decision/scenario modeling that requires new financial assumptions must wait for explicit user confirmation of those assumptions.

## 6. Cartões
- [x] Operating backend/manual cycle update exists; actual/open bill is separated from known-installment projection.
- [x] Aeternum Sep/2026 documentary update remains R$ 17,967.48 with 64 documentary lines closing to zero delta.
- [x] C6 production detail recovered: 347 rows / R$ 58,727.98.
- [x] 34 historical category-allocation cycles are certified exact.
- [x] Visa Infinite Itaú 2025 is 12/12 certified exact.
- [x] Mastercard Itaú 2025 certified months: Mar, Apr, May, Jun, Aug, Nov.
- [x] Candidate cockpit presents open exposure, next outflow, contracted installments, classification pending, bill agenda, 12M history and existing drilldown; card limits are not invented when undocumented.
- [~] Visual redesign remains pending real user homologation.
- [~] Mastercard Itaú 2025 Jan/Feb/Jul/Oct remain candidate-only until full signed category composition is recovered and independently summed.
- [ ] Mastercard Itaú 2025 Sep remains blocked: matrix R$ 26,582.10 vs ledger R$ 26,558.28; signed Crédito -R$0.13 does not explain full delta.
- [ ] Mastercard Itaú 2025 Dec remains blocked: matrix R$ 14,062.17 vs ledger R$ 13,195.37; signed Crédito -R$0.03 does not explain full delta.
- [~] Mastercard Itaú 2024 pending exact-recovery cycles: Jan `evento_base:1829` R$53,652.87; Feb `1871` R$58,667.61; Apr `1966` R$47,802.70; Jun `2061` R$48,393.80; Jul `2104` R$51,947.18; Nov `2281` R$45,259.24.
- [~] Extend history/evolution per card, future installments, category composition and merchant drilldown where evidence supports it.
- [~] Continue semantic classification of remaining unclassified purchases without inventing merchant/category.
- [ ] C6 Aug/2024 R$66.70 individual-detail gap remains blocked until documentary evidence is found.

## 7. Patrimônio
- [x] Executive model separates market estimates, documentary debt, equity, liquidity, restricted contingency and future awards.
- [x] Current documented model: CIPÓ central estimate R$5.2m (range R$4.6–5.8m), own asking price R$5.9m excluded as independent comp; CIPÓ documentary debt R$1,779,905.50.
- [x] Volvo current debt uses documentary R$110,492.81 and never treats R$173,185.80 future payment schedule as current debt.
- [x] Net worth central currently ~R$3.5728m with documented analytical range preserved in wealth model; wealth QA 18/18 PASS.
- [~] Patrimônio visual remains unhomologated because user has not inspected it since v135 baseline.
- [~] Refine Volvo market value only when trim/km evidence becomes available; current market range remains provisional.
- [ ] Build net-worth history only when evidence coverage permits; do not backfill unsupported valuations.

## 8. CIPÓ 396 / property reconciliation
- [x] 40 exact documentary mortgage installments loaded through 20/12/2029; contract tail remains explicit through 20/06/2052 with TR dependency and no fabricated exact tail values.
- [x] Purchase/reform/improvement source values and several rubrics already reconcile; Serviços e Mão de Obra sign-loss discrepancy resolved to source R$125,488.36.
- [~] Finish rubric-by-rubric source vs ledger reconciliation, especially Condomínio, Consórcio Itaú and remaining energy/operating-property differences.
- [~] Preserve acquisition, improvements, operating property expenses and financing as separate economic concepts across Despesas/Patrimônio.
- [ ] Condomínio source/ledger formula-cut difference remains unresolved.
- [ ] Consórcio Itaú source R$19,508.10 vs raw ledger R$19,811.70 delta R$303.60 remains unresolved; do not infer correction.
- [ ] Post-2029 contractual tail must remain documentary/conditional under TR rather than being silently treated as zero or exact.

## 9. Semantic classification
- [x] User-confirmed rules have priority; people names are not researched invasively; unsafe auto-classification remains blocked.
- [x] Main matcher optimized from ~2.65s to ~0.314s across 5,224 lines with 0 row/column differences.
- [x] Ambiguous exact key `cartão c6master` explicitly preserves legacy resolution path; do not change its classification priority without a real classification decision.
- [x] Save patches affected expense-cache rows incrementally and uses scoped classification refresh: card-only ~0.66s; semantic-only ~1.75s.
- [x] `lts_classification_cache_consistency_qa_v1` PASS 5/5 protects payload v36, live/cache parity and RPC exposure.
- [x] Browser semantic feedback remains authenticated=true / anon=false; internal scoped helper remains unavailable to browser roles.
- [~] Real authenticated save → cache → UI click path still needs browser validation.
- [~] Research merchant/vendor evidence before asking the user when appropriate, without inventing matches.
- [~] Propagate confirmed identical/history-safe classifications where contract allows.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.
- [ ] Never infer remaining bank classification from visual order/screenshots without a reliable transaction match.

## 10. Inputs / documents
- [x] Private upload/storage infrastructure and direct upload inside Atualizações exist.
- [x] Document lifecycle v2 read model now adds `document-change-summary-v1` while preserving lifecycle phases/summary exactly versus v1.
- [x] `lts_document_change_summary_v1` summarizes only actually applied targets; supports multi-entry applications plus legacy/simple fallback through `applied_target/applied_id`.
- [x] Documented card purchases are explicitly labeled as no bank-cash effect before invoice reconciliation.
- [x] Current resolved legacy/simple document was verified against its actual target and can show account/date/value/category/cost center/counterparty without inference.
- [x] `lts_document_lifecycle_qa_v1` now protects v2 contract and passes 17/17.
- [x] `lts_updates_fix86plus_v10` and browser lifecycle RPC now expose lifecycle v2 additively; no write semantics changed.
- [x] `lts_browser_product_v1` performs one Updates-only self-heal if a same-day cache still lacks `document-change-summary-v1`, avoiding a global financial refresh for schema transition.
- [x] Candidate v139 renders compact `O que mudou` rows for applied documents with details collapsed and no internal IDs in the primary reading.
- [~] Current same-day cache remains lifecycle-v1 until the next authenticated product load triggers the Updates-only self-heal; direct manual refresh was blocked by tool safety before execution.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [~] Ensure future upload UI clearly shows exactly what changed and what still requires a decision; backend is implemented, visual authenticated validation remains pending.
- [ ] User review should ultimately be limited to exceptions/ambiguities rather than routine document processing.

## 11. Performance / refresh architecture
- [x] Despesas browser read reduced from ~29.2s to ~0.20s via exact-parity cache-backed model.
- [x] Flow future 33-day read reduced from ~4.59s to ~13ms via exact-parity cache slice.
- [x] Semantic matcher reduced ~2.65s → ~0.314s; semantic queue base ~2.45s → ~0.88s.
- [x] Planning executive reduced ~9.84s → ~3.96s with full JSON parity.
- [x] Confirmation writes reduced ~18.8s → ~2.93s by targeted refresh with economic invariance proved.
- [x] Manual invoice update uses targeted financial refresh; 9 affected modules equal the full refresh output.
- [x] No small write remains coupled to the global operational refresh.
- [x] Same-day `lts_browser_product_v1` cache hit avoids global refresh entirely.
- [~] Global stale/day-rollover refresh remains ~18.8s; optimize further only where module-by-module parity is proved.
- [ ] Avoid global recomputation on daily initialization only if universal invalidation/freshness guarantees can be proved; never trade correctness for speed.
- [~] Final real authenticated browser latency still needs validation.

## 12. Data quality / regression gates
- [x] FIX86 canonical regression architecture retained.
- [x] Expense v9 latest: 19/19 PASS; 34/34 certified cycles close.
- [x] Expense v10 latest: 18/18 PASS.
- [x] Core financial regression latest: 15/15 PASS after lifecycle v2/health v14 changes.
- [x] Planning QA latest: 23/23 PASS.
- [x] Wealth QA: 18/18 PASS.
- [x] Expense read-cache QA: 3,767/3,767 and R$8,623,752.53 with 0 mismatch.
- [x] Classification cache consistency QA: 5/5 PASS.
- [x] Document lifecycle/change-summary QA: 17/17 PASS.
- [x] Operational cache health upgraded to v14 and PASS; transitional cache-v1 is accepted, while lifecycle-v2 requires `document-change-summary-v1`.
- [x] Flow cache QA v2 PASS; browser Flow v4 auth-only.
- [x] Permanent read-only candidate smoke CI PASS on run 33273277469; current v139 inline JavaScript passed Node parser and all required/forbidden candidate checks.
- [~] Modernize stale string/version expectations when architecture advances, but never weaken semantic/financial guardrails merely to make a gate green.

## 13. Historical recovery / evidence gaps
- [x] Canonical historical effective rows: 3,767; recovered category-detail rows: 3,449; certified category-allocation cycles: 34.
- [x] Remaining aggregate fallback: 318 rows totaling R$2,714,803.16; these do not need to reach zero before visual homologation.
- [x] Raw historical cash is not rewritten by analytic card-category recovery; signed credits/reversals are preserved where documented.
- [~] File Library currently repeatedly fails with `RetrievalClientResponseError`; this is a technical retrieval failure, never evidence that a missing category/reversal can be inferred.
- [~] Retry File Library later for Mastercard 2025 Jan/Feb/Jul/Oct and six pending Mastercard 2024 cycles.
- [~] Continue updating `HISTORICAL_RECOVERY_LOG.md` and immutable snapshots after every material exact-recovery batch.
- [ ] Do not certify any historical cycle unless source identity, complete signed category composition and ledger total close to the cent.

## 14. Open Finance
- [x] Provider-neutral architecture and private Supabase staging with RLS/idempotency exist; no bank credentials/tokens are stored in LTS tables.
- [~] Research provider feasibility/coverage for Itaú, Bradesco and C6, including card coverage, refresh lifecycle and failure modes.
- [~] Evaluate cost/consent/security before any financially binding provider decision.
- [ ] Real provider connection + consent + automated ingestion/reconciliation requires explicit user decision before contracting/consent; manual upload remains fallback.

## 15. UX / executive quality
- [x] Despesas has executive period context, history, rankings/trends and drilldown.
- [x] Cartões and Planejamento have materially new cockpit layouts in candidate rather than the rejected generic reports.
- [x] Atualizações candidate prioritizes actions and compresses methodology; classification confidence/history/options are direct and evidence-backed.
- [x] Applied-document changes now have compact candidate UI with details collapsed.
- [~] Continue replacing explanatory-only cards with evidence-backed interaction where backend support exists.
- [~] Make all empty/decision states actionable; avoid passive blank areas.
- [~] Consistent desktop/mobile behavior still requires real authenticated visual verification.
- [ ] Never call a report-like page a cockpit merely because it has KPI cards; first screen must answer the user’s decision question visually.

## 16. Backup / continuity
- [x] `PROJECT_MASTER_BACKLOG.md` remains the canonical persistent list of open work.
- [x] `HISTORICAL_RECOVERY_LOG.md` preserves historical evidence/blocked cycles.
- [x] `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` preserves real homologation failures.
- [x] `NEXT_HOMOLOGATION_GATE.md` tracks the minimum evidence before the next user look.
- [x] Immutable checkpoints include:
  - `backups/historical-recovery-2026-08-29.json`
  - `backups/historical-recovery-2026-08-29-batch2.json`
  - `backups/mastercard-itau-pending-ledger-map-2026-08-29.json`
  - `backups/wip35-v137-candidate-smoke-2026-08-29.txt`
  - `backups/wip35-v139-progress-2026-08-29.json`
  - `backups/wip35-v139-performance-batch2-2026-08-29.json`
  - `backups/wip35-v139-performance-updates-batch3-2026-08-29.json`
  - `backups/wip35-v139-document-lifecycle-batch4-2026-08-29.json`
  - `backups/wip35-v139-candidate-smoke-ci-2026-08-29.txt`
- [x] No user manual save is currently required.
- [ ] Add automated periodic repository/data snapshot workflow only after proving that it cannot expose credentials or private raw documents.