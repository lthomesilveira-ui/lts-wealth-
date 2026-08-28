# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

## 1. Atualizações / Central de manutenção
- [x] Checklist-first layout and reduced dead space.
- [x] Ledger check: verify whether a transaction is considered and whether it enters Despesas.
- [x] Checks for statements, card bills, financing balance, salary and IPVA coverage.
- [x] Manual card bill update by card + competence + amount.
- [x] Direct document upload inside Atualizações published in WIP35-v134.
- [x] Classification save regression patched with explicit error feedback; write path protected from the previous heavy/full refresh behavior.
- [x] Assisted classification UX shows confidence, recurrence/installment evidence, research/evidence and exact user decision needed.
- [x] Category selector widened/responsive to avoid truncating long category names.
- [ ] Document lifecycle status: received → interpreted → reconciled → decision needed → resolved.
- [ ] Resolved items must disappear immediately and reliably after write/refresh.

## 2. Despesas
- [x] Main definition includes effective spending/commitments and avoids duplicate card bill settlement, own transfers and non-expense asset movements.
- [x] C6 recovered production detail: 347 rows / R$ 58,727.98; Aug/2024 R$ 66.70 documentary gap remains open/do-not-infer.
- [x] Historical data available from 10/10/2013.
- [x] WIP35-v134 executive redesign: user-facing language and explicit period controls.
- [x] Full 2013→current annual series and monthly history exposed.
- [x] Rankings by category, counterparty and cost center with explicit selected period; aggregate card fallbacks removed from user-facing counterparty ranking.
- [x] YTD vs prior YTD and last-12-month metrics added.
- [x] Technical coverage diagnostics moved to collapsible Data Quality area.
- [x] Recent documentary bridge closes the direct-account gap after the legacy realized table checkpoint; only bank-evidenced facts are included.
- [~] Drilldown from executive rankings/charts to original transaction.
- [~] Continue reducing unclassified and unassigned historical data without changing total economics.
- [ ] CIPÓ historical reconciliation by rubric/year against source spreadsheet without inference.

## 3. CIPÓ 396
- [x] Current documentary mortgage debt preserved.
- [x] 40 exact installments loaded through 20/12/2029.
- [x] Contract tail disclosed through 20/06/2052; 2030–2052 never treated as zero.
- [x] Historical purchase + reform / improvements values located in source workbook.
- [~] Rubric-by-rubric Excel vs ledger reconciliation.
- [~] Separate acquisition, improvements, operating property expenses and financing consistently across Despesas/Patrimônio.
- [ ] Documentary representation of post-2029 contractual tail without fabricating TR-dependent installments.

## 4. Patrimônio
- [x] WIP35-v134 executive view answers assets / known debts / estimated net worth / D+3 liquidity.
- [x] Liquid assets, restricted FGTS, illiquid assets, debts and future awards are separated.
- [x] CIPÓ view separates market estimate, documentary debt, estimated equity and historical purchase+reform basis.
- [x] Volvo debt semantics use documented financing value and never sum all future payments as current debt.
- [x] Own CIPÓ asking price is explicitly not treated as an independent comparable.
- [~] Strengthen independent market-comparable evidence for CIPÓ.
- [~] Refine market value for armored Volvo XC40 2019/2020 Avalon when trim/km evidence becomes available.
- [ ] Net-worth history when evidence coverage permits.

## 5. Planejamento
- [x] Liquidity ladder: cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS D30.
- [x] Horizon extends beyond year-end and gap episodes are modeled beyond Jan/2027.
- [x] FGTS modeled as emergency contingency with lead time, not immediate cash.
- [x] WIP35-v134 executive redesign shows runway, layer transitions, gap episodes and recovery dates.
- [x] Updated card bills feed forward cash; Aeternum 28/08 evidence moved the first real modeled gap to 08/01/2027.
- [x] FGTS request-by date / residual uncovered gap are exposed from current model.
- [ ] Decision scenarios only after explicit financial assumptions are confirmed by user.

## 6. Cartões
- [x] Card/invoice operating view and manual cycle amount update.
- [x] Aeternum Sep/2026 updated from Bradesco open statement dated 28/08/2026 to R$ 17,967.48; 64 documentary lines reconcile to zero delta.
- [~] History/evolution per card, future installments, category composition and drilldown.
- [x] Actual/open bill is distinguished from known-installment projection in Atualizações.
- [~] Continue semantic classification of remaining unclassified purchases.
- [ ] Close C6 Aug/2024 R$ 66.70 documentary gap only with evidence.

## 7. Fluxo Diário
- [x] Mature daily reconciled flow with bank split/consolidated and liquidity columns.
- [x] Updated Aeternum obligation affects forward flow and projection bridge.
- [x] New documentary bridge to Despesas does not duplicate card bill settlement or own transfers.
- [~] Maintain visually distinct balance/sum rows and keep regression coverage as new modules evolve.
- [ ] Final real authenticated visual E2E.

## 8. Classificação semântica
- [x] User-confirmed rules have priority; safe auto-classification guarded.
- [x] People names are not researched invasively on public internet.
- [x] Save error UX patched and classification refresh reduced from prior full/heavy behavior.
- [x] Confidence + recurrence/installment + evidence shown in Atualizações.
- [~] Research merchant/vendor before asking user when appropriate.
- [~] Propagate confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.

## 9. Data quality / reconciliation
- [x] FIX86 canonical gates retained.
- [x] Projection bridge frozen baseline with explained deltas.
- [x] Core financial regression 15/15 after future-open-invoice horizon fix.
- [x] WIP35-v134 specific QA 20/20 and smoke parser 9/9 scripts green.
- [~] Modernize stale/legacy regression expectations as architecture evolves.
- [~] Health checks for new modules.
- [ ] Reduce historical card aggregate fallback as documentary detail is recovered.

## 10. Open Finance
- [x] Persistent repository issue created for Open Finance / automatic bank updates.
- [~] Research provider/architecture feasibility for Itaú, Bradesco and C6, including card coverage.
- [~] Evaluate cost, consent, authentication/security, refresh lifecycle and failure modes before any paid/financially binding choice.
- [ ] Implement automated ingestion + reconciliation; manual uploads remain fallback.

## 11. Inputs / documents
- [x] Private storage/upload infrastructure exists.
- [x] Direct upload inside Atualizações published in WIP35-v134.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [ ] Show clearly what changed after each upload.
- [ ] User should review only exceptions/ambiguities.

## 12. Performance
- [x] Heavy classification refresh identified and fast/targeted classification patch introduced.
- [~] Reduce refresh latency further and patch only affected modules.
- [ ] Avoid full rebuild for small actions in all write workflows.

## 13. UX / executive quality
- [x] Despesas primary screen moved from programmer/debug language to executive/user-facing report.
- [x] Patrimônio and Planejamento received executive hierarchy in WIP35-v134.
- [x] Period controls/labels added to Despesas metrics and rankings.
- [~] Add drilldowns and richer interactions instead of more text cards.
- [~] Consistent desktop/mobile behavior requires real visual verification.
- [ ] Empty states and decision states must be actionable across all tabs.

## 14. Release / homologation
- [x] Candidate-shell smoke pipeline preserves previous public version on failure.
- [x] WIP35-v134 published after specific QA 20/20, FIX86 20/20, financial regression 15/15, projection bridge green, smoke parser 9/9 and GitHub Pages success.
- [x] WIP35-v134 is now the public baseline/fallback for the next material candidate.
- [ ] Real authenticated visual E2E and multimodal certification remain explicitly unclaimed/pending.
- [ ] Next homologation after v134 should again be a material package, not a microbuild.
