# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

## 0A. Execução pós-homologação — WIP35-v138 candidate
- [x] Despesas: raiz do `canceling statement due to statement timeout` diagnosticada. A leitura v10 levava ~29,2s porque reconstruía repetidamente o universo efetivo histórico.
- [x] Despesas: criada `lts_expense_effective_read_cache` derivada exatamente de `lts_expense_total_rows_v5`; checkpoint atual 3.767 linhas / R$ 8.623.752,53.
- [x] Despesas: novo read model cacheado `lts_expense_executive_report_v12_cached` + browser RPC `lts_browser_expense_executive_v4`; benchmark ~0,20s no ano atual versus ~29,2s anterior, com deltas R$0,00 em total selecionado, conta, cartões, financiamento, imóvel e histórico.
- [x] Despesas: QA permanente `lts_expense_effective_read_cache_qa_v1` PASS: 3.767/3.767, R$8.623.752,53, 0 missing, 0 extra, 0 mismatch.
- [~] Despesas: v138 já usa o RPC rápido na candidata; ainda falta validar o carregamento autenticado real no navegador antes de encerrar o incidente de homologação.
- [x] Fluxo Diário: removida recomputação desnecessária desde a âncora para períodos exclusivamente futuros; paridade de 30 dias provada com delta máximo R$0,00.
- [x] Fluxo Diário: criada `lts_daily_flow_full_query_v6` para evitar cálculo futuro duplicado; próximos 30 dias passaram de ~5,58s para ~2,81s mantendo 30/30 dias e 13/13 eventos idênticos à v5.
- [x] Fluxo Diário: QA permanente `lts_flow_future_fast_path_qa_v1` PASS com threshold 5s e comparação v5=v6.
- [x] Classificação: corrigido bug de refresh que ainda procurava `lts-product-fix86-v35`; refresh rápido agora atualiza o payload atual v36.
- [x] Classificação: `lts_browser_semantic_feedback_v1` agora atualiza incrementalmente apenas as linhas afetadas do cache de Despesas, sem rebuild completo dos 13 anos.
- [x] Atualizações/classificação: medição real = 48 grupos pendentes, 62 opções disponíveis para todos, 9 com sugestão baseada em evidência e 0 auto-classificáveis seguros; v138 diferencia sugestão real de ausência de evidência sem fabricar categoria.
- [x] Atualizações/classificação: v138 recoloca confiança em `%` somente quando existe `suggestion_confidence` real e expõe sinal curto de histórico/evidência; justificativa detalhada fica recolhida.
- [~] Classificação: teste SQL em `ROLLBACK` do RPC browser foi bloqueado corretamente pelo guardrail de autenticação; write E2E autenticado real continua pendente e não é alegado como testado.
- [x] Cartões: novo cockpit v138 implementado sobre dados existentes de `card_operating`/`card_history`: faturas abertas, próxima pressão, parcelas contratadas, classificação pendente, agenda por cartão, histórico 12m e drilldown existente. Limite não é exibido sem evidência documental.
- [x] Planejamento: novo cockpit v138 implementado sobre `planning_executive`/`planning_ladder`: primeiro gap, pior ponto, buffer, FGTS D+30, linha temporal das camadas, episódios negativos, principais saídas, recuperações e transição v131 recolhida.
- [x] WIP35-v138 consolidada em `wip35-v138-candidate.html` + `wip35-v138-cockpits.js`; parser/smoke estático local verde e cockpit sem novos writes/RPCs financeiros.
- [x] GitHub Pages publicou a v138 consolidada com sucesso no run 33268994790, head `3781639c...`.
- [x] Gates após as mudanças: Despesas v9 19/19, v10 18/18, core financeiro 15/15, cache QA PASS e Flow fast-path QA PASS.
- [~] WIP35-v138 permanece candidata isolada. `index.html`/v136 continua fallback; não promover antes de QA autenticado/material e nova homologação.
- [ ] Real authenticated visual E2E continua pendente/não alegado.

## 0. Homologação V135 → V137 — feedback visual 2026-08-29
- [ ] CRÍTICO ORIGINAL: Despesas falhou ao carregar na homologação real com `canceling statement due to statement timeout`. Correção backend/candidata registrada em 0A; homologação real ainda pendente.
- [ ] CRÍTICO ORIGINAL: o usuário não considera Planejamento v136/v137 um cockpit executivo nem aderente ao layout/ambição previamente desenhados. Redesign v138 implementado; ainda não homologado visualmente.
- [ ] CRÍTICO ORIGINAL: Cartões v136/v137 foi rejeitada visualmente como relatório genérico. Redesign v138 implementado; ainda não homologado visualmente.
- [~] Atualizações melhorou materialmente na percepção do usuário, mas ainda requer homologação funcional e redução de densidade textual.
- [~] Atualizações / identificação: v138 restaura percentual de confiança quando há score real; validar na próxima homologação.
- [~] Atualizações / identificação: v138 mostra sinal curto de histórico/evidência; validar distinção encontrado / não encontrado / não verificado no uso real.
- [~] Atualizações / cobertura: backend confirmou 62 opções para todos os 48 itens; v138 mostra explicitamente os 39 sem sugestão segura e os 9 com sugestão baseada em evidência.
- [~] Atualizações / texto: v138 reduz texto principal e recolhe metodologia/evidência longa; validar densidade final na próxima homologação.
- [ ] A homologação efetiva do usuário parte da V135; portanto Patrimônio, Planejamento v136 e mudanças v137/v138 não ficam aprovadas só porque passaram QA técnico.
- [ ] Não pedir nova homologação até concluir os gates autenticados possíveis, parser/smoke/gates e manter fallback seguro.
- [ ] Real authenticated visual E2E continua não realizado/não alegado. O feedback fotográfico do usuário prevalece sobre smoke estático.

## 1. Atualizações / Central de manutenção
- [x] Checklist-first layout and reduced dead space.
- [x] Ledger check: verify whether a transaction is considered and whether it enters Despesas.
- [x] Checks for statements, card bills, financing balance, salary and IPVA coverage.
- [x] Manual card bill update by card + competence + amount.
- [x] Direct document upload inside Atualizações published in WIP35-v134.
- [x] Classification save regression patched with explicit error feedback; write path protected from the previous heavy/full refresh behavior.
- [x] Assisted classification backend/UI carries confidence, recurrence/installment evidence, research/evidence and exact user decision needed where available.
- [x] Category selector widened/responsive to avoid truncating long category names.
- [x] WIP35-v137 isolated candidate adds explicit lifecycle vocabulary: Recebido → Interpretado → Reconciliado → Decisão necessária → Resolvido, without inferring completed state from absence in the active queue.
- [x] WIP35-v138 candidate makes action/confidence/history/decision the primary classification reading and keeps detailed rationale collapsible.
- [x] WIP35-v138 candidate renders category options for every eligible card-classification item and explicit evidence-based no-suggestion state when appropriate.
- [x] WIP35-v138 candidate shows direct confidence percentage only from real score/evidence fields.
- [~] Persist full document lifecycle status per document/item in backend instead of UI-only possible-stage vocabulary.
- [~] Resolved items must disappear immediately and reliably after write/refresh; existing effective-operation guardrails remain green but full per-document lifecycle persistence is still open.

## 2. Despesas
- [x] Main definition includes effective spending/commitments and avoids duplicate card bill settlement, own transfers and non-expense asset movements.
- [x] Historical data available from 10/10/2013.
- [x] WIP35-v134 executive redesign: user-facing language and explicit period controls.
- [x] WIP35-v135 month-by-month and year-by-year report across the full available history.
- [x] Rolling 3/6/12-month windows with total, monthly average, financing and category composition.
- [x] Current partial month is compared with the same elapsed days of prior month / prior year.
- [x] Rankings and trends show the period explicitly.
- [x] Monthly drilldown v2 reaches the rows forming the month.
- [x] Category-known coverage and individual transaction/merchant detail are shown as different levels.
- [x] Certified historical card category allocation replaces technical aggregates with R$0 economic delta and without inventing merchants.
- [x] Technical coverage diagnostics moved to collapsible Data Quality area.
- [x] Recent documentary bridge closes the direct-account gap after the legacy realized checkpoint; only bank-evidenced facts are included.
- [x] Historical signed-value corrections/reversals are applied analytically without rewriting raw cash history; permanent QA protects the documented source refs.
- [x] Historical expense total remains invariant at R$ 8,623,752.53 after the 2026-08-29 recovery batch 2.
- [x] WIP35-v137 isolated candidate makes category ranking and 12-month category trend interactive: click opens an evidence-backed category focus, then month drilldown delegates to the existing certified month-detail RPC. No merchant/purchase is fabricated when evidence does not exist.
- [x] Backend timeout architecture fixed with effective read cache + v12 cached executive report; browser candidate v138 wired to `lts_browser_expense_executive_v4`.
- [~] Real authenticated browser load must still be validated before marking the homologation timeout fully closed.
- [~] Extend drilldown further where merchant-level evidence exists across the whole selected range, not only via monthly category focus.
- [~] Continue reducing unclassified/unassigned history without changing total economics.
- [~] Recover more historical card cycles only where invoice/category composition closes exactly.
- [ ] CIPÓ historical reconciliation by rubric/year against source spreadsheet without inference.

## 3. CIPÓ 396
- [x] Current documentary mortgage debt R$ 1,779,905.50 preserved separately from projected cash outflow.
- [x] 40 exact installments loaded through 20/12/2029.
- [x] Contract tail disclosed through 20/06/2052; 2030–2052 never treated as zero; TR dependency explicit.
- [x] Historical purchase + reform / improvements values located in source workbook.
- [x] Serviços e Mão de Obra sign-loss discrepancy reconciled to source: R$ 125,488.36 after three documented negative adjustments.
- [x] Several rubrics already close to source (financing/Sonho, IPTU, marmoraria, marcenaria, arquitetura, automação, móveis, serralheria and others).
- [~] Finish rubric-by-rubric Excel vs ledger reconciliation, especially Condomínio, Consórcio Itaú and remaining energy/operating-property differences.
- [~] Separate acquisition, improvements, operating property expenses and financing consistently across Despesas/Patrimônio.
- [ ] Documentary representation of post-2029 contractual tail without fabricating TR-dependent installments.

## 4. Patrimônio
- [x] WIP35-v136 backend/read model answers: how much I have, owe and net worth today.
- [x] Backend `wealth_executive` read model separates market estimates, documentary debt, equity, liquidity, restricted contingency and future awards.
- [x] Net worth central R$ 3.572.800,64 with analytical market range R$ 2.947.800,64–R$ 4.202.800,64 at current evidence.
- [x] CIPÓ central market estimate R$ 5.2m, range R$ 4.6–5.8m; own R$ 5.9m asking price explicitly excluded as independent comparable.
- [x] CIPÓ equity central R$ 3.420.094,50 and historical purchase+reform kept separate from market value/tax basis.
- [x] Volvo XC40 provisional market central R$ 170k, range R$ 145–200k; trim/km uncertainty explicit.
- [x] Volvo current financed balance uses R$ 110,492.81; R$ 173,185.80 future payment schedule is never treated as current debt.
- [x] Liquid assets, restricted FGTS, illiquid assets and future awards are separated.
- [x] Permanent wealth QA 18/18 protects valuation/debt semantics and recalculation idempotency.
- [~] Visual homologation remains pending because user's effective baseline is V135; do not mark v136 presentation approved.
- [~] Refine Volvo market value when trim/km evidence becomes available.
- [ ] Net-worth history when evidence coverage permits.

## 5. Planejamento
- [x] Liquidity ladder: cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS D+30.
- [x] Planning ladder now explicitly uses the same Flow v12 basis; 366-day parity against prior ladder had zero numeric delta.
- [x] Backend/read model explains first gap, amount, causes and recovery.
- [x] Current first real gap is 08/01/2027; worst modeled gap in the current horizon is R$ -21,046.80.
- [x] Three negative episodes are explained with their key outflows and recovery inflows.
- [x] Old v131 12/01/2027 baseline is preserved and explained by a counterfactual: without Volvo first gap 10/01; without Volvo + IPVA it returns exactly to 12/01.
- [x] FGTS remains emergency contingency with ~30-day lead time; request-by date for first gap is 09/12/2026 and it does not cover the full current horizon.
- [x] Permanent planning QA 23/23 protects numeric parity, episodes, FGTS semantics and transition explanation.
- [x] REDESIGN candidate v138: cockpit visual com first gap, worst point/buffer, FGTS D+30, timeline de camadas/gaps, episódios, drivers e recovery; sem novas premissas financeiras.
- [~] Redesign ainda depende de homologação visual real; não marcar aprovado por smoke estático.
- [ ] Decision scenarios only after explicit financial assumptions are confirmed by user.

## 6. Cartões
- [x] Card/invoice operating backend and manual cycle amount update.
- [x] Aeternum Sep/2026 updated from Bradesco open statement dated 28/08/2026 to R$ 17,967.48; 64 documentary lines reconcile to zero delta.
- [x] C6 recovered production detail: 347 rows / R$ 58,727.98.
- [x] 34 historical category-allocation cycles are now certified exact in Supabase after the 2026-08-29 recovery batch 2.
- [x] Visa Infinite Itaú 2025 is 12/12 certified exact with signed evidence where reversals/credits exist.
- [x] Mastercard Itaú 2025 certified months currently include Mar, Apr, May, Jun, Aug and Nov. Mar closes exactly at R$ 37,905.32 from 28 nonzero categories / 67 source occurrences with original signed Crédito = 0; Nov closes at R$ 5,883.96 after preserving original signed Crédito -R$0.01.
- [x] REDESIGN candidate v138: cockpit com exposição aberta, próxima saída, parcelas contratadas, classificação pendente, agenda de faturas, histórico 12m e drilldown existente; não inventa limite.
- [~] Redesign ainda depende de homologação visual real.
- [~] Mastercard Itaú 2025 Jan/Feb/Jul/Oct remain candidate-only until complete category lists are recovered and independently summed.
- [ ] Mastercard Itaú 2025 Sep remains blocked: matrix R$ 26,582.10 vs ledger R$ 26,558.28; Crédito -R$0.13 does not explain the full delta.
- [ ] Mastercard Itaú 2025 Dec remains blocked: matrix R$ 14,062.17 vs ledger R$ 13,195.37; large signed/reversal delta unresolved.
- [~] Mastercard Itaú 2024 pending exact-recovery ledger identities: Jan evento_base:1829 R$53,652.87; Feb:1871 R$58,667.61; Apr:1966 R$47,802.70; Jun:2061 R$48,393.80; Jul:2104 R$51,947.18; Nov:2281 R$45,259.24.
- [~] History/evolution per card, future installments, category composition and merchant drilldown.
- [x] Actual/open bill is distinguished from known-installment projection in Atualizações.
- [~] Continue semantic classification of remaining unclassified purchases.
- [ ] Close C6 Aug/2024 R$ 66.70 documentary gap only with evidence; do not infer.

## 7. Fluxo Diário
- [x] Mature daily reconciled flow with bank split/consolidated and liquidity columns.
- [x] Flow v12 is the canonical operational basis used by the current Planning ladder.
- [x] Updated Aeternum obligation affects forward flow and projection bridge.
- [x] Documentary bridge to Despesas does not duplicate card bill settlement or own transfers.
- [x] Future-only read path optimized in v6: 30-day engine ~2.81s vs ~5.58s v5 with exact day/event parity.
- [x] Permanent `lts_flow_future_fast_path_qa_v1` requires v5=v6 and latency <5s for 30-day future read.
- [~] Real authenticated browser retest remains pending before marking the user-observed timeout fully closed.
- [~] Maintain visually distinct balance/sum rows and regression coverage as modules evolve.
- [ ] Final real authenticated visual E2E.

## 8. Classificação semântica
- [x] User-confirmed rules have priority; safe auto-classification guarded.
- [x] People names are not researched invasively on public internet.
- [x] Save error UX patched and classification refresh reduced from prior heavy/full behavior.
- [x] Refresh version mismatch v35→v36 corrected.
- [x] Save path incrementally patches affected Despesas cache rows rather than rebuilding all history.
- [x] Confidence + recurrence/installment + evidence shown in Atualizações where data exists.
- [x] v138 presents confidence/history/suggestion consistently and category options for all eligible card review items; no suggestion is fabricated for the 39 groups without evidence.
- [~] Real authenticated write/refresh click path still requires validation; SQL session impersonation was correctly blocked by auth guardrail.
- [~] Research merchant/vendor before asking user when appropriate.
- [~] Propagate confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.
- [ ] Remaining semantic bank decisions must not be inferred from visual order/screenshots without a reliable transaction match.

## 9. Data quality / reconciliation
- [x] FIX86 canonical gates retained.
- [x] Projection bridge uses frozen baseline with explained deltas; current max residue ~R$ 0.019 below R$ 0.03 tolerance.
- [x] Core financial regression 15/15 remains green after WIP35-v138 performance/flow changes.
- [x] Expense v9 permanent QA protects total invariance and historical allocation replacement; latest run 19/19 with 34/34 certified cycles closing.
- [x] Expense v10 latest run 18/18 PASS.
- [x] Wealth QA 18/18 and Planning QA 23/23 are permanent.
- [x] WIP35-v136 specific QA 32/32.
- [x] WIP35-v136 smoke: 11/11 inline scripts passed Node parser; all required/forbidden checks green.
- [x] WIP35-v137 isolated candidate static smoke 12/12 + Node parser PASS; no direct RPC/write path added.
- [x] Despesas performance/load architecture gate added through exact cache QA; cached executive read benchmark ~0.20s vs ~29.2s old path.
- [x] Flow future performance/parity gate added: `lts_flow_future_fast_path_qa_v1` PASS.
- [x] Atualizações coverage measured: 48/48 items have category options, 9 evidence-backed suggestions, 39 explicit no-suggestion cases, 0 unsafe auto-classification.
- [~] Modernize stale legacy regression expectations as architecture evolves rather than forcing current models to old bugs.
- [~] Reduce historical card aggregate fallback as documentary detail is recovered.

## 10. Open Finance
- [x] Persistent repository issue created for Open Finance / automatic bank updates.
- [x] Provider-neutral architecture documented in repository.
- [x] Neutral private Supabase staging/schema created with RLS and no bank credentials/tokens stored in LTS tables.
- [x] Staging idempotency tested: same provider record does not duplicate effect.
- [~] Research provider feasibility/coverage for Itaú, Bradesco and C6, including card coverage.
- [~] Evaluate cost, consent, authentication/security, refresh lifecycle and failure modes before any paid/financially binding choice.
- [ ] Implement real provider connection + consent + automated ingestion/reconciliation; manual upload remains fallback.

## 11. Inputs / documents
- [x] Private storage/upload infrastructure exists.
- [x] Direct upload inside Atualizações published in WIP35-v134.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [ ] Show clearly what changed after each upload.
- [ ] User should review only exceptions/ambiguities.

## 12. Performance
- [x] Heavy classification refresh identified and fast/targeted classification patch introduced.
- [x] Payload v36 can patch Planning/Wealth without forcing unrelated modules to rebuild.
- [x] Despesas heavy browser read replaced in v138 candidate by exact-parity cache-backed read (~0.20s backend benchmark).
- [x] Fluxo future path reduced from ~5.58s to ~2.81s with exact parity gate.
- [x] Semantic classification save now patches affected expense-cache rows incrementally.
- [~] Real authenticated browser latency still needs final verification before user retest.
- [~] Reduce refresh latency further and patch only affected modules.
- [ ] Avoid full rebuild for small actions in all write workflows.

## 13. UX / executive quality
- [x] Despesas primary screen uses executive/user-facing language and explicit period context when it loads.
- [x] WIP35-v135 added month/year/rolling-window history and drilldown.
- [x] Backend models for Patrimônio/Planejamento were rebuilt around user questions in v136; visual presentation is not homologated.
- [x] WIP35-v138 candidate implements materially new Cartões and Planejamento cockpits instead of the rejected report-like layouts.
- [x] WIP35-v138 candidate reduces Atualizações classification copy density and restores direct confidence/history signals with complete option coverage.
- [~] Consistent desktop/mobile behavior still requires real authenticated visual verification.
- [~] Continue replacing explanatory-only cards with evidence-backed interaction where the backend supports it.
- [ ] Empty states and decision states must be actionable across all remaining tabs.

## 14. Release / homologation
- [x] Candidate-shell smoke pipeline preserves previous public version on failure.
- [x] WIP35-v135 published after expense-specific QA and smoke.
- [x] WIP35-v136 backend/data package passed prior technical gates, but its report-tab visual presentation is not user-approved.
- [x] WIP35-v136 remains current public canonical baseline/fallback only.
- [x] WIP35-v137 isolated candidate created at `wip35-v137-candidate.html`; candidate commit `31d604e8...` received successful GitHub Pages build/deployment run 33265232777.
- [x] WIP35-v137 candidate static QA 12/12, Node parser, expense v9 19/19, expense v10 18/18 and core financial regression 15/15 are green.
- [x] WIP35-v137 FAILED real user homologation gate on 2026-08-29: Despesas statement timeout plus Planejamento/Cartões visual rejection; Atualizações direction improved but remained incomplete. Do not promote to index.
- [x] WIP35-v138 isolated candidate created and consolidated with performance/classification/cockpit package; Pages run 33268994790 success on head `3781639c...`.
- [x] WIP35-v138 static scripts parse; financial gates remain green; v136 index remains untouched.
- [~] WIP35-v138 is NOT yet promoted and should not be sent for another user look until remaining authenticated checks are exhausted and checkpoint is complete.
- [ ] Real authenticated visual E2E and multimodal certification remain explicitly unclaimed/pending.

## 15. Backup / continuity
- [x] `PROJECT_MASTER_BACKLOG.md` remains the canonical persistent list of open work.
- [x] `HISTORICAL_RECOVERY_LOG.md` persists historical-recovery evidence, guardrails, certified/blocked cycles and next work outside chat memory; batch 2 includes Mastercard Mar/2025.
- [x] `backups/historical-recovery-2026-08-29.json` preserves the first versioned recovery checkpoint.
- [x] `backups/historical-recovery-2026-08-29-batch2.json` preserves the immutable 34-cycle checkpoint after Mastercard Mar/2025 certification.
- [x] `backups/mastercard-itau-pending-ledger-map-2026-08-29.json` persists the exact ledger identities for pending Mastercard 2024 recovery.
- [x] `backups/wip35-v137-candidate-smoke-2026-08-29.txt` persists candidate smoke, financial gates and guardrails.
- [x] `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md` persists real homologation failures and execution response.
- [~] Create immutable WIP35-v138 performance/cockpit checkpoint after this batch and keep master backlog synchronized.
- [~] Update recovery log + immutable snapshot + master backlog after each material historical-recovery batch.
- [ ] Add automated periodic repository/data snapshot workflow only after validating that it does not expose credentials or private raw documents.
