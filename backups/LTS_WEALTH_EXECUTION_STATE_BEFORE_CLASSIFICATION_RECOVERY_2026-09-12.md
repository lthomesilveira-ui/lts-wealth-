# LTS Wealth — Execution State

Latest update: 12/09/2026, single-list invoice reading order, bank-context UX and actual classification-readiness audit. Prior complete state is preserved unchanged at backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_LINEAR_CATEGORIES_2026-09-12.md. All unaffected requirements and financial confirmations remain binding.

## Tested product / publication boundary
- Version remains V162; approved functional reference V150/V151. Tested package d3300083bc1288cb0c5aff1772f98877ef17728e contains the product from 37bddb251c86e3eed4e813f56cca7093645dc395 plus a test-only asynchronous wait correction.
- Fixed homologacao.html -> wip35-v162-candidate.html. The manifest selects this package; check the resulting main Pages and post-manifest workflows before claiming live publication. Protected public index.html remains unchanged, promotion_status not_promoted.
- Recovery smoke 34726662187: SUCCESS. Default-window 34726456351: SUCCESS. Integrated invoices + bank-context + category-geometry gate 34726456372: SUCCESS. Artifact and inspected screenshots are recorded in backups/V162_LINEAR_CATEGORIES_ACCEPTANCE_2026-09-12.md.
- No new financial or classification writes occurred in this UI package. The private readiness audit is a record, not a ledger change.

## Latest user feedback / implemented UI
The user says the inspected Flows now appear correct. They want invoice categories in a single readable descending sequence instead of searching across two columns, and ask when the accumulated classifications can begin. This is not full acceptance of every product module or a release of bulk classification.

Every supported invoice family now uses a single vertical category/value list, largest net total first. Category is left, amount right; the summary totals/pending-actions panel remains separate. This applies to open/closed summary and full detail; source purchase order, financial amounts and category assignments were not changed. Contract invoice-single-list-descending-v1.

The package also includes the previously prepared bank-switch correction: changing banks or Consolidado closes expanded days and invoice summary/full/loading context, keeps the chosen period, and discards late invoice responses. Returning to a bank starts closed; clicking the same active bank preserves its disclosure. Closing a pending invoice or collapsing its owning day cannot be undone by a late response. Contract bank-switch-closes-days-and-invoices-v1. Default D-5 through D+30 inclusive remains unchanged. No additional wrapper chain, permanent observer or polling was added.

## Classification readiness — concrete blockers found
Real authenticated read-only consumer queries found that current open Aeternum detail and the Updates classification queue still use different snapshots. The detail uses the verified current source, while the queue uses older legacy cycle detail; pending counts and amounts disagree. The Flow semantic queue reports zero groups while actual bank/Flow events still show missing categories. Do not present the queue as complete or ask the user to redo all classifications from scratch.

The existing exact-description save function can return saved=true with a deferred cache-refresh failure. The protected browser handler checks the transport error but not that refresh result before displaying success. Earlier stateful fixture save/reload PASS is not proof that all current real sources are synchronized.

Bulk manual classification is therefore NOT released. Its blocker is source/readback consistency, not the Dashboard, Work credits, another upload or a new chat. Private source_documents audit_key invoice_linear_classification_readiness_20260912_v1 preserves the exact current/queue comparison, pending bank-event sample, save-path findings and source screenshot archived in private Drive. No merchant/category was guessed in this audit.

## Next execution package — highest priority after this UI exposure
1. Align review queues with the exact current invoice and bank/Flow sources, retaining earlier snapshots as history and avoiding duplicate purchases.
2. Recover already-known original-spreadsheet and confirmed LTS mappings first. User decisions outrank heuristics; distinguish genuine unknowns from lost linkage. Both bank movements and card purchases are in scope, including review/reclassification from the Flow.
3. Preserve Categoria/Grupo/Macrogrupo, existing cost centers and semantic scope. Do not turn an intermediary description into a global guessed classification or invoice payment into new consumption. Do not invent replacement taxonomy to remove pending labels.
4. Validate save -> rule persistence -> refreshed queue -> invoice/Flow readback. Surface saved-but-not-reflected status rather than false complete success; invalidate affected semantic/Flow caches without changing money. Retain the actual user-session gate separately from controlled tests.
5. Only after these source and save/readback gates pass, explicitly release the remaining user-dependent classifications. Do not delegate basic source-consistency QA to the user.

## Preserve earlier financial truth and open dependencies
The current Itaú statement remains applied; separate due/cash dates, current Aeternum source, C6 fee/reversal and prior-payment exclusion remain. Preserve the financing edit, revised same-obligation Larissa payment, one Volvo insurance Pix, separate dated Cofrinho, vested-only current awards and rejected Mercado Pago DDA.

The specific Bradesco yield residual was confirmed and applied; its warning is resolved. Never reopen that exact occurrence as unexplained or generalize it into a tolerance for every cent difference. Older same-residual items in the backlog/gates are superseded by backups/V162_BRADESCO_YIELD_CONFIRMED_2026-09-12.md.

Other-Visa current documentary identity gaps, the earlier Bradesco opening report not captured as an invoice error, real-session classification persistence and human whole-product approval remain tracked. Dashboard is outside this package and requires a full approved image before implementation. Complete remaining list is PROJECT_MASTER_BACKLOG.md + PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md + latest execution/checkpoint overrides; no unrelated item was deleted.

## Restart / write protocol
Read this file, PROJECT_START_HERE.md, latest checkpoint, NEXT_HOMOLOGATION_GATE.md, master backlog/delta, decision ledger, LTS_WEALTH_CONTINUITY_HANDOFF.md and CANONICAL_DELIVERY_MASTER_PLAN.md. Refresh main and recovery-v152-flow-20260910 before writes, re-read changed/relevant documents, never force or overwrite parallel changes. User updates use Concluído / Em execução / Próximos passos. Data application, consumer readback, isolated browser test, publication and user approval remain distinct.
