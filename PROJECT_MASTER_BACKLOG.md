# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

## 0. Homologação V135 → V137 — feedback visual 2026-08-29
- [ ] CRÍTICO: Despesas falhou ao carregar na homologação real com `canceling statement due to statement timeout`. Não considerar a aba homologável até corrigir performance/query e testar o caminho real de carregamento.
- [ ] CRÍTICO: o usuário não considera Planejamento v136/v137 um cockpit executivo nem aderente ao layout/ambição previamente desenhados. Reprojetar a aba como cockpit visual de decisão, reduzindo relatório textual, premissas longas e explicações empilhadas na tela principal.
- [ ] CRÍTICO: Cartões v136/v137 foi rejeitada visualmente como relatório genérico. Reprojetar como cockpit de cartões/faturas, com hierarquia visual, leitura imediata de exposição, vencimentos, evolução, parcelas futuras, composição e drilldown; não tratar os cards/gráfico atuais como entrega final.
- [~] Atualizações melhorou materialmente na percepção do usuário, mas ainda requer homologação funcional e redução de densidade textual.
- [ ] Atualizações / identificação: restaurar/expor de forma direta o percentual de confiança da sugestão quando houver score real, sem fabricar confiança quando o backend não a fornecer.
- [ ] Atualizações / identificação: mostrar de forma curta e evidente se há histórico comparável para o lançamento/merchant e qual é a evidência histórica disponível; preservar distinção entre `há histórico`, `não encontrado` e `não verificado`.
- [ ] Atualizações / cobertura: corrigir o caso em que opções/sugestões de classificação aparecem apenas para os primeiros itens da fila; todos os itens elegíveis devem receber opções ou uma explicação explícita baseada em evidência de por que não há sugestão.
- [ ] Atualizações / texto: reduzir texto principal e empurrar metodologia/evidência longa para expansão secundária, mantendo ação, confiança, histórico e decisão necessária na primeira leitura.
- [ ] A homologação efetiva do usuário parte da V135; portanto Patrimônio e Planejamento v136 e as mudanças v137 ainda não estão aprovadas só porque passaram QA técnico.
- [ ] Não pedir nova homologação até haver pacote visual material de report tabs + Despesas carregando sem timeout + cobertura de sugestões em Atualizações + parser/smoke/gates verdes.
- [ ] Real authenticated visual E2E continua não realizado/não alegado. O feedback fotográfico do usuário é evidência de falha visual real e deve prevalecer sobre smoke estático.

## 1. Atualizações / Central de manutenção
- [x] Checklist-first layout and reduced dead space.
- [x] Ledger check: verify whether a transaction is considered and whether it enters Despesas.
- [x] Checks for statements, card bills, financing balance, salary and IPVA coverage.
- [x] Manual card bill update by card + competence + amount.
- [x] Direct document upload inside Atualizações published in WIP35-v134.
- [x] Classification save regression patched with explicit error feedback; write path protected from the previous heavy/full refresh behavior.
- [x] Assisted classification backend/UI already carries confidence, recurrence/installment evidence, research/evidence and exact user decision needed where available; homologation requires making confidence/history direct again and ensuring coverage across all eligible items.
- [x] Category selector widened/responsive to avoid truncating long category names.
- [x] WIP35-v137 isolated candidate adds explicit lifecycle vocabulary: Recebido → Interpretado → Reconciliado → Decisão necessária → Resolvido, without inferring completed state from absence in the active queue.
- [ ] Reduce primary-copy density: action first; confidence/history/decision immediately visible; detailed rationale collapsible.
- [ ] Ensure classification suggestion/options are generated/rendered for every eligible active item, not only the first items; distinguish no suggestion because evidence is insufficient from a rendering/coverage bug.
- [ ] Restore direct confidence percentage only from real score/evidence fields; never derive a percentage from visual order or arbitrary heuristic.
- [ ] Restore direct historical-match signal per item: comparable history found / no comparable history found / not checked, with source/count when available.
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
- [ ] Fix real browser timeout observed in homologation before any next user review; performance must be tested against the actual authenticated expense load, not only QA RPCs/static parser.
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
- [ ] REDESIGN: current v136/v137 visual presentation rejected in real homologation; replace report-like stacked narrative with the intended executive cockpit, while preserving the certified backend semantics.
- [ ] Decision scenarios only after explicit financial assumptions are confirmed by user.

## 6. Cartões
- [x] Card/invoice operating backend and manual cycle amount update.
- [x] Aeternum Sep/2026 updated from Bradesco open statement dated 28/08/2026 to R$ 17,967.48; 64 documentary lines reconcile to zero delta.
- [x] C6 recovered production detail: 347 rows / R$ 58,727.98.
- [x] 34 historical category-allocation cycles are now certified exact in Supabase after the 2026-08-29 recovery batch 2.
- [x] Visa Infinite Itaú 2025 is 12/12 certified exact with signed evidence where reversals/credits exist.
- [x] Mastercard Itaú 2025 certified months currently include Mar, Apr, May, Jun, Aug and Nov. Mar closes exactly at R$ 37,905.32 from 28 nonzero categories / 67 source occurrences with original signed Crédito = 0; Nov closes at R$ 5,883.96 after preserving original signed Crédito -R$0.01.
- [ ] REDESIGN: current v136/v137 Cards presentation rejected in real homologation as generic/report-like; build an executive cards cockpit rather than iterating the current KPI-card + bar-chart layout.
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
- [~] Maintain visually distinct balance/sum rows and regression coverage as modules evolve.
- [ ] Final real authenticated visual E2E.

## 8. Classificação semântica
- [x] User-confirmed rules have priority; safe auto-classification guarded.
- [x] People names are not researched invasively on public internet.
- [x] Save error UX patched and classification refresh reduced from prior heavy/full behavior.
- [x] Confidence + recurrence/installment + evidence shown in Atualizações where data exists.
- [ ] Ensure confidence/history/suggestion presentation is consistently available for all eligible update items rather than only early queue entries.
- [~] Research merchant/vendor before asking user when appropriate.
- [~] Propagate confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.
- [ ] Remaining semantic bank decisions must not be inferred from visual order/screenshots without a reliable transaction match.

## 9. Data quality / reconciliation
- [x] FIX86 canonical gates retained.
- [x] Projection bridge uses frozen baseline with explained deltas; current max residue ~R$ 0.019 below R$ 0.03 tolerance.
- [x] Core financial regression 15/15 remains green after WIP35-v137 candidate creation.
- [x] Expense v9 permanent QA protects total invariance and historical allocation replacement; latest run 19/19 with 34/34 certified cycles closing.
- [x] Expense v10 latest run 18/18 PASS.
- [x] Wealth QA 18/18 and Planning QA 23/23 are permanent.
- [x] WIP35-v136 specific QA 32/32.
- [x] WIP35-v136 smoke: 11/11 inline scripts passed Node parser; all required/forbidden checks green.
- [x] WIP35-v137 isolated candidate static smoke 12/12 + Node parser PASS; no direct RPC/write path added.
- [ ] Add a performance/load gate for Despesas because static/QA gates did not catch the real browser statement timeout.
- [ ] Add Atualizações coverage QA: every eligible classification item must expose suggestion/options or an explicit evidence-based no-suggestion state; confidence/history signals must map to real backend evidence.
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
- [ ] CRÍTICO: eliminate Despesas statement timeout observed in real browser homologation.
- [~] Reduce refresh latency further and patch only affected modules.
- [ ] Avoid full rebuild for small actions in all write workflows.

## 13. UX / executive quality
- [x] Despesas primary screen uses executive/user-facing language and explicit period context when it loads.
- [x] WIP35-v135 added month/year/rolling-window history and drilldown.
- [x] Backend models for Patrimônio/Planejamento were rebuilt around user questions in v136; visual presentation is not homologated.
- [ ] CRÍTICO: redesign report tabs as coherent executive cockpits. Planejamento and Cartões current layouts are explicitly rejected by user homologation.
- [~] Atualizações direction is positively received, but reduce copy density and restore direct confidence/history signals with full eligible-item coverage.
- [~] WIP35-v137 isolated candidate adds richer Despesas interactions and explicit Atualizações lifecycle/workflow framing, but candidate is not approved due current homologation failures.
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
- [ ] WIP35-v137 FAILED real user homologation gate on 2026-08-29: Despesas statement timeout plus Planejamento/Cartões visual rejection; Atualizações direction improved but remains incomplete. Do not promote to index.
- [ ] Next candidate must include material report-tab redesign, real Despesas load/performance validation, and consistent Atualizações classification coverage before asking user to inspect again.
- [ ] Real authenticated visual E2E and multimodal certification remain explicitly unclaimed/pending.

## 15. Backup / continuity
- [x] `PROJECT_MASTER_BACKLOG.md` remains the canonical persistent list of open work.
- [x] `HISTORICAL_RECOVERY_LOG.md` persists historical-recovery evidence, guardrails, certified/blocked cycles and next work outside chat memory; batch 2 includes Mastercard Mar/2025.
- [x] `backups/historical-recovery-2026-08-29.json` preserves the first versioned recovery checkpoint.
- [x] `backups/historical-recovery-2026-08-29-batch2.json` preserves the immutable 34-cycle checkpoint after Mastercard Mar/2025 certification.
- [x] `backups/mastercard-itau-pending-ledger-map-2026-08-29.json` persists the exact ledger identities for pending Mastercard 2024 recovery.
- [x] `backups/wip35-v137-candidate-smoke-2026-08-29.txt` persists candidate smoke, financial gates and guardrails.
- [x] 2026-08-29 real homologation failures and Atualizações feedback are persisted in this master backlog; they must not depend on chat memory.
- [~] Update recovery log + immutable snapshot + master backlog after each material historical-recovery batch.
- [ ] Add automated periodic repository/data snapshot workflow only after validating that it does not expose credentials or private raw documents.
