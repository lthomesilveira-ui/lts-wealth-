# V162 — New Aeternum open snapshot applied

Date: 2026-09-11. This package processes the newly supplied five-page Bradesco open statement, emitted at 20:00 on 11/09. It is separate from the earlier blocked Itaú checking-account reconciliation. That blocked transaction was not retried or routed elsewhere.

## Source verification
- The five-page image-only PDF was visually reviewed without OCR. Ninety-eight source rows were transcribed: 96 current-cycle charge rows, one prior-balance row and its equal/opposite prior-payment row.
- The 96 charge-row sum equals the sum of the five printed section subtotals, with zero difference. Summing all 98 signed rows yields the same total.
- Printed section totals have a prior-balance allocation inconsistency between two card sections. Preserve printed subtotals and visual-section charge sums separately; do not relocate a purchase or fabricate a line to force per-instrument agreement.
- The positive row named PAGAMENTO is retained as printed; it is not the negative prior-cycle debit settlement.
- Status remains Em Aberto. The current PDF does not print the due date, purchase years or installment counters. The existing September due date was preserved, not inferred from this PDF. No purchase year or installment sequence was guessed.

## Applied, with readback
The allowed data-only transaction locked and checked the existing open invoice, recorded its before-image in owner-scoped source_documents, updated the same billing obligation through lts_card_invoice_manual_update_core_v1, then attached the 96 verified source items and documentary provenance. A source-checksum idempotency guard prevents repeating the operation.

The invoice remains open, with source document_pdf_open. No additional September obligation, bank transaction or closed-expense row was created. The previous prior-payment row was not posted to the bank again. The old 64-row legacy fatura/compra_parcelada snapshot remains intact and is explicitly identified in current metadata as historical rather than the current source. The active open reader uses metadata.items; do not quote the old legacy reconciliation view as proof of the new snapshot.

Both future Flow caches were invalidated. lts_refresh_product_read_cache_invoice_v1 then completed successfully, refreshing the existing product read cache. No schema, grants, RLS, authentication or frontend was changed.

## Consumer QA
Under PostgreSQL role authenticated with controlled database claims and an eight-second limit, lts_browser_flow_v11 returned exactly one current Aeternum September cash projection at the updated source total. lts_browser_card_settlement_detail_v2 returned matched=true, open_cycle=true, all 96 current source rows and the same exact sum. Neither prior-balance nor prior-payment row was returned as a purchase. This is database consumer QA, not the user's signed-in browser or physical-iPhone E2E. Open-cycle arithmetic reconciliation is not evidence of payment or closure.

The existing reader reused its existing project rules/history for categories; no new rule was invented. Unclassified lines remain pending. The current reader can omit source dates and infer card-final context from history instead of using newly captured visual-source fields; improving source-accurate detail remains part of the presentation/linkage work.

## Private evidence
The exact original PDF and verified extraction are preserved in a private Drive ZIP, indexed by the source_documents record with document_type credit_card_invoice, reference_date 2026-09-11 and processing_status applied_open_snapshot. Metadata contains checksum, archive retrieval pointer/member names, raw row values, before-images, preserved due-date basis, printed totals, application receipt and non-recognition-as-closed-expenses boundaries. No private amounts, source lines, document IDs or credentials belong in this public checkpoint.

## Remaining gates
- All cards still require the same approved Aeternum inline summary, confirmed LTS names/categories, descending category totals, explicit pending items and full documented-invoice navigation. Open/closed UI parity was not implemented in this data package.
- The original Itaú checking-account reconciliation block is still open; its PDF is already preserved. Do not request another upload or claim this new-card success corrected Itaú cash.
- Preserve Itaú Personnalite recognition and due-date/cash-date lookup defects, the C6 unclassified-credit presentation issue, other Visa identity/evidence gaps and real browser classification persistence gate.
- Default D-5 through D+30, historical facts, financing edit, user-confirmed Larissa/insurance/Cofrinho decisions and rejection of the unrelated DDA remain unchanged.
- Dashboard remains out of scope, bulk classification unreleased and public-root promotion unauthorized. Keep every other dependency in PROJECT_MASTER_BACKLOG.md and historical checkpoints.
