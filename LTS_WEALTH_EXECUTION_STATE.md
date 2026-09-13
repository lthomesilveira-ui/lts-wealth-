# LTS Wealth — Execution State

Business date 12/09/2026, America/Sao_Paulo. Latest action: the user explicitly required the assistant to execute classifications rather than ask the user to wait. A first evidence-based classification batch and source-consistency fixes were applied to the private backend and reread. This is not a claim that all accumulated classification is complete.

Prior state is preserved byte-for-byte at backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_CLASSIFICATION_RECOVERY_2026-09-12.md. All unaffected obligations, financial confirmations and historical evidence remain binding.

## Applied and verified
- Six exact-descriptor aliases restore documented LTS mappings for specific observed supplier/financial-charge descriptions. They are system_high historical recoveries, not fabricated user-confirmed decisions. No generic marketplace, gift purpose or ambiguous personal Pix was inferred.
- Three bank-event categories were recovered individually from prior historical classifications and documentary replacement links. Their financial source rows, amounts and dates remain unchanged.
- A documented C6 annual-fee reversal was assigned to the same category as its matching fee, on that one source line only. No global rule for all tariff reversals was created.
- The Flow read now recovers an existing valid specific financial-event category when the presentation had incorrectly returned pending. It does not overwrite an already non-pending effective category or alter financial fields.
- Across the checked August-to-October Flow and the three current invoices, 16 entries moved from pending to classified: nine card lines and seven bank/Flow lines. Four of those seven Flow recoveries exposed categories already stored in their specific source; three were applied in this batch.
- The current C6 invoice has zero pending classification lines. Other invoices still have pending items; exact counts, values and changed rows are stored privately in the audit.

## Concrete source blockers corrected
- The current open-invoice queue now reads the SAME source and semantic reader as the current Flow invoice. Its current source replaces the old same-family/same-due-date queue slice without rewriting or duplicating purchases. Current Aeternum queue/detail pending counts and values agree; current closed Mastercard and C6 also agree.
- The bank semantic queue includes effective current-bank sources as well as the preserved legacy queue. It no longer returns an empty list while current Flow events remain pending. Original signed evidence is retained per entry. The old UI's total_outflow name is a display-amount compatibility alias in this review queue, not a cash calculation.
- The exact-description writer now refreshes BOTH review scopes and rejects a failed refresh rather than reporting completed success. The write and refresh roll back together on failure. Source/semantic Flow caches are invalidated after successful verification.
- Internal invoice-core and queue helpers are denied to anon/authenticated direct callers; user-facing authenticated signatures remain unchanged. No authentication/RLS boundary was relaxed.

## Evidence actually obtained
Private source_documents audit_key history_classification_recovery_20260912_v1 contains authorization, original rule lineage, bank/credit before-images, baseline consumer payloads, changed entries, before/after invoice counts and QA PASS. Assertions verified identical daily monetary payloads, event counts, invoice totals, source lines, raw descriptions and dates. The classification cache was refreshed and reread.

The actual browser semantic RPC was additionally exercised under role authenticated in a transaction that was rolled back: a newly recovered safe alias was temporarily hidden inside that isolated transaction, the known correct category was saved, and invoice/product readback agreed with no remaining queue entry for the descriptor. No test changes became externally visible or were committed. This is a database writer/readback probe, NOT a user browser or physical-iPhone session test.

## Version and publication
Frontend remains the already published V162 single-list/bank-scope package, product d3300083bc1288cb0c5aff1772f98877ef17728e, published via e098b5472d6432a035fb436828fcf16fac353f9c. No frontend file or manifest changed in this classification batch. The same fixed homologation reads the applied backend data on reload. Public index.html remains protected and promotion_status stays not_promoted. Earlier publication evidence: backups/V162_LINEAR_CATEGORIES_PUBLICATION_2026-09-12.md.

Latest checkpoint: backups/V162_CLASSIFICATION_RECOVERY_APPLIED_2026-09-12.md.

## Continue classifying, do not turn technical blockers into user homework
The assistant is responsible for recovering and applying already-supported classifications. The user should be asked only about remaining real semantic decisions, grouped where appropriate. Current remaining ambiguity includes competing historical restaurant taxonomies and generic processors/marketplace/personal-Pix purposes; do not infer those solely from amount or company type. Confirmed transaction-specific decisions outrank global rules. Retain Categoria/Grupo/Macrogrupo and the existing cost-center scheme.

Full historical recovery, transaction-scoped manual reclassification (rather than unsafe global supplier rules), browser actual-session save/refresh/reopen and complete review presentation remain open. Do not announce bulk manual classification as fully released merely because this backend batch passed. Do not use that manual gate to postpone further safe assistant-applied recovery. The queue may now show more items than before because previously omitted sources are included; they are not new expenses.

## Preserved boundaries
Preserve original files, protected historical financial facts, Bradesco yield resolution, reconciled Itaú bank cash, separate invoice due/cash dates, source-correct Aeternum detail, C6 prior-payment exclusion, all financing edits, Larissa adjustment, one insurance obligation, separate dated Cofrinho and vested-only availability. The default five prior days plus today plus thirty future days, single descending invoice list and bank-switch disclosure closure remain unchanged.

Current other-Visa documentary identities, the earlier uncaptured Bradesco opening report, human product approval and every unrelated backlog item remain tracked. Dashboard remains out of scope pending explicit approved image; public-root promotion unauthorized.

## Restart / writes
Refresh main and recovery-v152-flow-20260910 and read this state, latest checkpoint, NEXT_HOMOLOGATION_GATE.md, complete PROJECT_MASTER_BACKLOG.md plus delta, decision ledger, LTS_WEALTH_CONTINUITY_HANDOFF.md and CANONICAL_DELIVERY_MASTER_PLAN.md before repository writes. Never force or overwrite parallel changes. User updates: Concluído / Em execução / Próximos passos. Distinguish source recovery, classification application, consumer readback, database probe, browser test, publication and human approval.
