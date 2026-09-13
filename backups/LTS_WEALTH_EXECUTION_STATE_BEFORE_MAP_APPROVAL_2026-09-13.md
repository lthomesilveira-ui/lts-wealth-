# LTS Wealth — Execution State

Latest update: 13/09/2026. User-confirmed historical category Restaurantes applied to the identified current invoice purchases. Complete prior execution state is preserved byte-for-byte in backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_RESTAURANTES_2026-09-13.md; all unaffected requirements and financial confirmations remain binding.

## Current classification decision — do not ask again
The user confirms Restaurantes is the original Excel category used in the history since 2013 and chooses to retain it to consolidate the two pending migration months. For this recovery, the existing Excel/LTS nomenclature remains authoritative. A nomenclature redesign is a later separate proposal, not a prerequisite or an implicit authorization to rename old data. The choice between Restaurantes and Restaurantes e Lazer for the identified restaurant purchases is now RESOLVED: use Restaurantes.

Do not globally merge all Restaurantes e Lazer records, as that label may include non-restaurant leisure. Do not infer a personal Pix, payment intermediary, marketplace purchase or food-delivery category from this decision alone. Historical user decisions and transaction-specific scopes remain authoritative. No new taxonomy, cost-center assignment, retrospective rename or classification-by-amount was authorized.

## Applied in this turn
Four identified purchase lines in the current September Aeternum source snapshot were classified as Restaurantes using the existing per-source category_lts mechanism, with user-confirmed provenance attached to each target. Three merchants were explicitly discussed; one has two charges. This is a targeted change, not a global supplier rule or a claim that all two months are now complete.

Before-images and decision text are preserved in private source_documents audit_key restaurantes_excel_user_confirmed_20260913_v1. The current invoice/source amount, raw descriptions, source dates, line identifiers and unrelated categories were verified unchanged. The prior August cycle was verified unchanged. The current invoice detail and refreshed classification queue agree; the four confirmed source lines no longer appear as pending. Post-commit reads through the authenticated consumer signature also passed. No schema, permissions, frontend, manifest or financial writer changed.

Latest immutable checkpoint: backups/V162_RESTAURANTES_EXCEL_CONFIRMATION_2026-09-13.md. It supersedes earlier suggestions that the restaurant category choice is still unanswered. It does not close other semantic, manual-UI or human-approval gates.

## Earlier classification package — preserved
The prior evidence-based batch recovered nine card lines and seven Flow/bank entries using existing mappings and source categories. Its C6 current invoice is fully classified. Current open-invoice detail/queue source parity, inclusion of pending current bank events, and atomic failure on classification-refresh errors were implemented and tested. Original records and before/after definitions remain in private audit history_classification_recovery_20260912_v1 and backups/V162_CLASSIFICATION_RECOVERY_APPLIED_2026-09-12.md.

This first batch and the four newly confirmed restaurant lines are separate applications. Do not overwrite the earlier audit or call them a complete two-month recovery. User input should be limited to real unresolved meaning after historical evidence retrieval; assistant-supported recovery is not blocked by manual-entry UX readiness.

## Version / operational references
Frontend remains published V162, tested product d3300083bc1288cb0c5aff1772f98877ef17728e, exposure e098b5472d6432a035fb436828fcf16fac353f9c, fixed homologacao.html -> wip35-v162-candidate.html. Publication receipt: backups/V162_LINEAR_CATEGORIES_PUBLICATION_2026-09-12.md. The same link reads the new classifications after reload; no new frontend build is required. Public index.html stays protected, promotion_status not_promoted.

Preserve single descending category lists, bank-switch disclosure closure, default five preceding days plus today plus thirty following days, manual date selection, source-correct invoice detail and due/cash-date separation. V150/V151 remains the functional reference. No cumulative wrapper runtime, permanent observer or polling is authorized.

## Continue the two-month recovery
Keep applying supported classifications to BOTH bank/Flow movements and card purchases with the existing Excel taxonomy. Retrieve existing source/rule history before asking; apply confirmed Restaurante decisions to actual restaurant evidence rather than creating a blanket leisure conversion. Preserve Categoria/Grupo/Macrogrupo and existing cost-center distinctions. Future naming proposals should use an explicit mapping and impact review without erasing original labels, and require approval before use.

Full historical recovery, per-transaction manual reclassification scope, manual UI/readback presentation, actual user-session save-refresh-reopen and unrestricted bulk-user release remain open. Database consumer tests do not equal physical-iPhone/user-session E2E. The user should not redo known classifications, and no additional permission is needed for already-authorized evidence-supported recovery.

## Other preserved boundaries
Keep reconciled Itaú cash, the confirmed Bradesco yield, separate dated Cofrinho, vested-only current awards, current source invoices, C6 prior-payment exclusion, financing edits, Larissa payment adjustment, one insurance obligation and rejected unrelated DDA. Current other-Visa documentary identities, the uncaptured Bradesco opening report and all unrelated master-backlog items remain tracked. Dashboard is out of scope until a complete proposed image is explicitly approved.

## Restart / write protocol
Refresh main and recovery-v152-flow-20260910, this state, latest checkpoint, NEXT_HOMOLOGATION_GATE.md, PROJECT_MASTER_BACKLOG.md plus its delta, decision ledger, LTS_WEALTH_CONTINUITY_HANDOFF.md and CANONICAL_DELIVERY_MASTER_PLAN.md before repository writes. Re-read changed/relevant sections. Never force branches or overwrite parallel changes. Concluído / Em execução / Próximos passos remain the user update headings. Distinguish evidence, classification decision, applied data, consumer readback, test scope, publication and human approval.
