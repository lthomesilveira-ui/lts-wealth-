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
- [x] Historical data available from 10/10/2013.
- [x] WIP35-v134 executive redesign: user-facing language and explicit period controls.
- [x] WIP35-v135 month-by-month and year-by-year report across the full available history.
- [x] Rolling 3/6/12-month windows with total, monthly average, financing and category composition.
- [x] Current partial month is compared with the same elapsed days of prior month / prior year.
- [x] Rankings and trends show the period explicitly.
- [x] Monthly drilldown v2 reaches the rows forming the month.
- [x] Category-known coverage and individual transaction/merchant detail are shown as different levels.
- [x] Certified historical card category allocation replaces 9 technical aggregates with R$0 economic delta; last-6-month category-known coverage increased without inventing merchants.
- [x] Technical coverage diagnostics moved to collapsible Data Quality area.
- [x] Recent documentary bridge closes the direct-account gap after the legacy realized checkpoint; only bank-evidenced facts are included.
- [x] Historical signed-value corrections/reversals are applied analytically without rewriting raw cash history; permanent QA protects the documented source refs.
- [~] Extend drilldown from category/rank/trend interactions to original transaction where merchant-level evidence exists.
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
- [x] WIP35-v136 executive view answers: how much I have, owe and net worth today.
- [x] Backend `wealth_executive` read model separates market estimates, documentary debt, equity, liquidity, restricted contingency and future awards.
- [x] Net worth central R$ 3.572.800,64 with analytical market range R$ 2.947.800,64–R$ 4.202.800,64 at current evidence.
- [x] CIPÓ central market estimate R$ 5.2m, range R$ 4.6–5.8m; own R$ 5.9m asking price explicitly excluded as independent comparable.
- [x] CIPÓ equity central R$ 3.420.094,50 and historical purchase+reform kept separate from market value/tax basis.
- [x] Volvo XC40 provisional market central R$ 170k, range R$ 145–200k; trim/km uncertainty explicit.
- [x] Volvo current financed balance uses R$ 110,492.81; R$ 173,185.80 future payment schedule is never treated as current debt.
- [x] Liquid assets, restricted FGTS, illiquid assets and future awards are separated.
- [x] Permanent wealth QA 18/18 protects valuation/debt semantics and recalculation idempotency.
- [~] Refine Volvo market value when trim/km evidence becomes available.
- [ ] Net-worth history when evidence coverage permits.

## 5. Planejamento
- [x] Liquidity ladder: cash → D0/D1 → vested RSU D3 → scheduled vestings conditional → FGTS D+30.
- [x] Planning ladder now explicitly uses the same Flow v12 basis; 366-day parity against prior ladder had zero numeric delta.
- [x] WIP35-v136 executive report explains when cash becomes negative, amount, causes and recovery.
- [x] Current first real gap is 08/01/2027; worst modeled gap in the current horizon is R$ -21,046.80.
- [x] Three negative episodes are explained with their key outflows and recovery inflows.
- [x] Old v131 12/01/2027 baseline is preserved and explained by a counterfactual: without Volvo first gap 10/01; without Volvo + IPVA it returns exactly to 12/01.
- [x] FGTS remains emergency contingency with ~30-day lead time; request-by date for first gap is 09/12/2026 and it does not cover the full current horizon.
- [x] Permanent planning QA 23/23 protects numeric parity, episodes, FGTS semantics and transition explanation.
- [ ] Decision scenarios only after explicit financial assumptions are confirmed by user.

## 6. Cartões
- [x] Card/invoice operating view and manual cycle amount update.
- [x] Aeternum Sep/2026 updated from Bradesco open statement dated 28/08/2026 to R$ 17,967.48; 64 documentary lines reconcile to zero delta.
- [x] C6 recovered production detail: 347 rows / R$ 58,727.98.
- [x] 9 additional historical category-allocation cycles certified with R$0 delta to their aggregates.
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
- [x] Confidence + recurrence/installment + evidence shown in Atualizações.
- [~] Research merchant/vendor before asking user when appropriate.
- [~] Propagate confirmed identical/history-safe classifications.
- [~] Resolve taxonomy conflicts without re-asking already-resolved decisions.
- [ ] Remaining semantic bank decisions must not be inferred from visual order/screenshots without a reliable transaction match.

## 9. Data quality / reconciliation
- [x] FIX86 canonical gates retained.
- [x] Projection bridge uses frozen baseline with explained deltas; current max residue ~R$ 0.019 below R$ 0.03 tolerance.
- [x] Core financial regression 15/15 remains green after payload v36.
- [x] Expense v9 permanent QA protects total invariance and historical allocation replacement.
- [x] Wealth QA 18/18 and Planning QA 23/23 are permanent.
- [x] WIP35-v136 specific QA 32/32.
- [x] WIP35-v136 smoke: 11/11 inline scripts passed Node parser; all required/forbidden checks green.
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
- [~] Reduce refresh latency further and patch only affected modules.
- [ ] Avoid full rebuild for small actions in all write workflows.

## 13. UX / executive quality
- [x] Despesas primary screen uses executive/user-facing language and explicit period context.
- [x] WIP35-v135 added month/year/rolling-window history and drilldown.
- [x] WIP35-v136 rebuilt Patrimônio and Planejamento around user questions instead of technical diagnostics.
- [x] Main Patrimônio view separates market, debt, equity and liquidity; methodology remains secondary.
- [x] Main Planejamento view explains liquidity layers, gap episodes, drivers and recovery.
- [~] Add richer interactions/drilldowns instead of more explanatory cards.
- [~] Consistent desktop/mobile behavior still requires real authenticated visual verification.
- [ ] Empty states and decision states must be actionable across all tabs.

## 14. Release / homologation
- [x] Candidate-shell smoke pipeline preserves previous public version on failure.
- [x] WIP35-v135 published after expense-specific QA and smoke.
- [x] WIP35-v136 published after backend payload v36, Wealth 18/18, Planning 23/23, candidate QA 32/32, financial regression 15/15, projection bridge green, 11/11 Node parser checks, smoke `publish=ready` and GitHub Pages success.
- [x] WIP35-v136 is the current public canonical baseline for the next material candidate.
- [ ] Real authenticated visual E2E and multimodal certification remain explicitly unclaimed/pending.
- [ ] Next homologation should again be a material package, not a microbuild.
