# V162 — User confirmations and C6 documentary import

Date: 2026-09-11. Scope: the five explicit replies following the real-data refresh checkpoint. This is not Dashboard work or public-root promotion.

## Confirmations applied

The revised September payment to Larissa replaces the existing health projection, rather than adding a second expense. The amount was changed through `lts_flow_mutate_v1` using an idempotency key and the existing append-only event-operation writer. The original event remains intact.

The October Pix to Larissa is the existing Volvo insurance payment. The existing event was enriched with recipient and confirmation provenance; no second cash event was created.

The Itaú investment total is the already-modeled Cofrinho. A dated position was appended without deleting or editing the previous dated position, and without inferring income, return or a cash transfer.

The Mercado Pago DDA boleto is not an obligation of the user. This explicit rejection is persisted privately and it remains absent from Flow. No banking payment/cancellation operation was performed.

## Archive processing and C6 reconciliation

The user's supplied password successfully opened the uploaded C6 ZIP. Neither the password value nor private financial source content is included in this repository. The extracted original CSV is separately preserved in the user's private Drive and indexed in the owner-scoped `source_documents` table.

The CSV has nine source records: six purchase/installment charges, one annual fee, its equal/opposite reversal, and a prior payment. Eight current-cycle detail records were imported into the existing `fatura` / `compra_parcelada` detail model. The prior payment is preserved as source evidence only, excluded from current consumption and from new bank postings.

The six charges match the previously documented C6 invoice. The existing invoice's bank-evidenced payment/date and paid status were retained. The filename date was not treated as proof of due date. The `lts_card_invoice_detail_reconciliation` view returns eight lines and zero difference against the existing invoice total.

Existing exact semantic rules were reused and canonicalized. Issuer categories remain raw evidence, not the adopted LTS classification. An unmatched description remains pending. Physical-versus-virtual card identity was not guessed.

## Snapshot guard

Applied Supabase migration `evidence_current_asset_latest_snapshot_guard_2026_09_11` changes only the asset-selection CTE in `lts_current_evidence_position_v1`. It selects the latest snapshot per `(asset_name, asset_type)` at or before the current date, ordered consistently with the existing effective-position reader. Historical snapshots remain intact and do not sum as extra current assets.

The generic applied patch is preserved in `backups/EVIDENCE_CURRENT_ASSET_LATEST_SNAPSHOT_GUARD_2026-09-11.sql`. It is idempotent and aborts if the expected original function fragment no longer matches. No grants, RLS policy, authentication boundary or financial writer was relaxed.

## Verified after writing

- Current Flow uses the confirmed health amount and contains no second original-value health debit.
- Insurance count for the documented date/value is exactly one.
- Rejected-boleto cash-event count is zero.
- Current Cofrinho resource equals the new documentary position; the earlier dated position remains separately queryable.
- The user's financing edit and the Itaú Mastercard cash-date/contractual-due-date separation are preserved.
- C6 detail has eight current-cycle rows, an exact total match and no duplicated source-line IDs.
- Consumer RPC `lts_browser_card_settlement_detail_v2` passed under PostgreSQL role `authenticated`, with controlled database claims and an explicit eight-second statement limit. It returned all eight rows and did not expose the prior payment as consumption. This is database-role QA, not browser/session/physical-device E2E.
- Card classification-review cache refresh succeeded. No new semantic rule or bulk user classification was invented.

## Private operational evidence

`source_documents` contains owner-scoped `user_confirmation` and `card_statement_csv` records at reference date 2026-09-11. They retain checksums, private Drive retrieval paths, original names, before-images, resolved decisions, application status and consumer-RPC QA. Password values are not stored. Monetary values remain in that private evidence, not in this public handoff.

Two failed pre-application attempts were rolled back before financial mutation. The subsequent confirmed-data and C6-import transactions completed and were read back successfully. Do not confuse a failed preflight with a partially applied financial update.

## Backlog delta and remaining gates

Closed: revised-health-payment identity/value decision; insurance-Pix identity decision; investment-total/Cofrinho identity decision; rejected-DDA disposition; encrypted-CSV readability and its C6 detail import.

Still open: material authenticated Flow homologation; the real browser classification save -> refresh -> readback/self-heal lifecycle; all-card invoice-model parity wherever detail exists; documentary identity of the small Bradesco card debit; every unrelated item retained in `PROJECT_MASTER_BACKLOG.md` and earlier evidence. Do not re-ask these five resolved questions or treat the original refresh checkpoint's corresponding questions as still open.

Bulk classification remains unreleased until the real browser lifecycle is proven. Dashboard requires a complete proposed image and explicit user approval. The frontend, `index.html` and public promotion status were not changed by this package.
