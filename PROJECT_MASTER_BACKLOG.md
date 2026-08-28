# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

## 1. Atualizações / Central de manutenção
- [x] Checklist-first layout and reduced dead space.
- [x] Ledger check: verify whether a transaction is considered and whether it enters Despesas.
- [x] Checks for statements, card bills, financing balance, salary and IPVA coverage.
- [x] Manual card bill update by card + competence + amount.
- [~] Direct document upload inside Atualizações (implemented in candidate WIP35-v133; pending release validation).
- [~] Fix classification save regression and decouple write from heavy refresh.
- [~] Restore assisted classification UX: confidence %, recurrence/installment evidence, internal/external evidence, exact user decision needed.
- [~] Ensure category dropdown never truncates long names.
- [ ] Document lifecycle status: received → interpreted → reconciled → decision needed → resolved.
- [ ] Resolved items must disappear immediately.

## 2. Despesas
- [x] Main definition includes effective spending/commitments and avoids duplicate card bill settlement, own transfers and asset movements.
- [x] C6 recovered production detail: 347 rows / R$ 58,727.98; Aug/2024 R$ 66.70 documentary gap remains open/do-not-infer.
- [x] Historical data exists from 10/10/2013.
- [~] Executive redesign: user-facing language, explicit period everywhere, no programmer vocabulary in primary view.
- [~] Full 2013→today annual series and monthly evolution.
- [~] Rankings by category, counterparty, cost center and origin with explicit period.
- [ ] YoY, YTD vs prior YTD, last-12-month comparisons.
- [ ] Drilldown to original transaction.
- [~] Separate technical data-quality diagnostics from executive report.
- [~] Reduce excessive Não atribuído and continue semantic enrichment.
- [ ] CIPÓ historical reconciliation by rubric/year against source spreadsheet without inference.

## 3. CIPÓ 396
- [x] Current documentary debt preserved.
- [x] 40 exact installments loaded through 20/12/2029.
- [x] Contract tail disclosed through 20/06/2052; 2030–2052 never treated as zero.
- [x] Historical cost / improvements values located in source workbook.
- [~] Rubric-by-rubric Excel vs ledger reconciliation.
- [~] Separate acquisition, improvements, operating property expenses and financing consistently across Despesas/Patrimônio.
- [ ] Documentary representation of post-2029 contractual tail without fabricating TR-dependent installments.

## 4. Patrimônio
- [x] Initial property/vehicle/debt structure and CIPÓ tail disclosure.
- [x] Volvo debt semantics use documented initial/current debt logic, never sum all future payments as current debt.
- [~] Executive redesign to answer: quanto tenho / quanto devo / patrimônio líquido.
- [~] Separate liquid assets, illiquid assets, debts and equity.
- [~] CIPÓ: historical cost vs improvements vs market value vs debt vs equity.
- [ ] Independent market comps for CIPÓ; own asking price cannot be treated as independent evidence.
- [ ] Refine market value for armored Volvo XC40 2019/2020 Avalon.
- [ ] Net-worth history when evidence coverage permits.

## 5. Planejamento
- [x] Liquidity ladder: cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS D30.
- [x] Horizon extends beyond year-end; Jan/2027 gap episodes preserved.
- [x] FGTS modeled as emergency contingency with lead time, not immediate cash.
- [~] Executive redesign and timeline of liquidity runway.
- [~] Show when each liquidity layer is exhausted.
- [~] Show deficit episodes/recovery in user language.
- [~] Reflect updated card bills in forward cash.
- [ ] Decision scenarios only after explicit financial assumptions are confirmed by user.

## 6. Cartões
- [x] Card/invoice operating view and manual cycle amount update.
- [x] Aeternum Sep/2026 updated from Bradesco open statement dated 28/08/2026 to R$ 17,967.48; 64 documentary lines reconcile to zero delta.
- [~] History/evolution per card, future installments, category composition and drilldown.
- [~] Distinguish actual bill vs known-installment floor vs projection.
- [~] Continue semantic classification of remaining unclassified purchases.
- [ ] Close C6 Aug/2024 R$ 66.70 documentary gap only with evidence.

## 7. Fluxo Diário
- [x] Mature daily reconciled flow with bank split/consolidated and liquidity columns.
- [x] Updated Aeternum obligation affects forward flow.
- [~] Keep new documentary inputs free of double counting.
- [~] Maintain visually distinct balance/sum rows.
- [ ] Final real authenticated visual E2E.

## 8. Classificação semântica
- [x] User-confirmed rules have priority; safe auto-classification guarded.
- [x] People names are not researched invasively on public internet.
- [~] Fix save UX/regression and performance.
- [~] Confidence + recurrence/installment + evidence UX.
- [~] Research merchant/vendor before asking user when appropriate.
- [~] Propagate confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.

## 9. Data quality / reconciliation
- [x] FIX86 canonical gates retained.
- [x] Projection bridge frozen baseline with explained deltas.
- [x] Core financial regression 15/15 after future-open-invoice horizon fix.
- [~] Modernize stale regression expectations as architecture evolves.
- [~] Health checks for new modules.
- [ ] Reduce historical card aggregate fallback as documentary detail is recovered.

## 10. Open Finance
- [x] Persistent repository issue created for Open Finance / automatic bank updates.
- [~] Research provider/architecture feasibility for Itaú, Bradesco and C6, including card coverage.
- [ ] Evaluate cost, consent, auth/security, refresh lifecycle and failure modes.
- [ ] Implement automated ingestion + reconciliation; manual uploads remain fallback.

## 11. Inputs / documents
- [x] Private storage/upload infrastructure exists.
- [~] Direct upload inside Atualizações candidate.
- [~] Improve automatic PDF/image interpretation and bank/card/competence association.
- [ ] Show clearly what changed after each upload.
- [ ] User should review only exceptions/ambiguities.

## 12. Performance
- [x] Heavy classification refresh identified and fast classification refresh introduced.
- [~] Reduce refresh latency further and patch only affected modules.
- [ ] Avoid full rebuild for small actions.

## 13. UX / executive quality
- [~] Reduce programmer/debug language in primary product views.
- [~] More KPIs, graphs, rankings, trends, comparisons, timelines and drilldowns; fewer text-only cards.
- [~] Explicit period on every metric/ranking.
- [~] Consistent desktop/mobile behavior.
- [ ] Empty states and decision states must be actionable.

## 14. Release / homologation
- [x] Candidate-shell smoke pipeline preserves previous public version on failure.
- [x] WIP35-v132 remains current fallback/public baseline until next candidate is green.
- [~] WIP35-v133 internal candidate: Atualizações upload + classification save robustness + Aeternum documentary refresh.
- [ ] Next homologation should be a materially improved package, not a microbuild.
- [ ] Real authenticated visual E2E and multimodal certification remain explicitly unclaimed/pending.
