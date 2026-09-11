# V162 — Current statement received, application blocked, card audit

Date: 2026-09-11. This is an evidence and continuity checkpoint, NOT a product release or a claim that the bank reconciliation was applied.

## Current Itaú statement is available

The user re-uploaded the complete checking-account statement covering 12/08 through 11/09 and emitted on 11/09 at 12:10 BRT. The original PDF, verified extraction and complete private audit are preserved in the user's Drive. Do not request the same statement again. The previous checkpoint's missing-current-statement condition is resolved as a document-availability issue, not as a database-application issue.

Private recovery filenames: `LTS_Wealth_Itau_Extrato_2026-09-11_121000.pdf`, `LTS_Wealth_Itau_2026-09-11_Extracao_Conferida.json`, and `LTS_Wealth_Conferencia_Contas_Cartoes_2026-09-11.md`. Retrieve these through the authorized Drive connection. The private audit contains original-file checksum, storage IDs, amounts, exact source lines, the old calculation, proposed reconciliation and before/after expectations. None of those financial amounts, private IDs or credentials is published here.

The extraction has 43 transaction lines. Its 19 daily closes after the opening reference reconcile arithmetically within the PDF at zero difference. This is source-document verification, not a claim that the 19 historical app balances are correct.

## Application attempt was blocked

The Supabase reconciliation transaction was blocked by the tool safety layer because it could not determine the request's safety status. A subsequent read confirmed that the older account anchor remained, the new statement's source-document record was absent and none of the six proposed new bank facts was inserted. Do not claim a partial or successful financial update. No alternate route was used to perform that blocked financial transaction.

No new bank amount, classification, replacement rule, balance snapshot, schema migration, cache mutation or frontend change was applied by this audit. This Git commit only records findings and handoff state. The remaining constraint is permitted execution and validation, not another user document or a request to repeat prior authorization.

The eventual authorized reconciliation must preserve source evidence and the original projections, avoid duplicated facts, link only the matching monthly obligations, retain raw descriptions and distinguish posting dates from dates embedded in bank descriptions. Do not invent a balancing entry, infer unknown Pix purposes or use investment/credit-limit values as checking-account cash.

## Other-account evidence boundary

The stored Bradesco current position agrees with the supplied balance screenshot; the previously recorded small historical residual remains unresolved. A matching position screenshot does not certify every intervening historical movement.

C6's supplied statement and effective historical reader agree on the two own-account movements and the single current card payment, ending at zero. No duplicate current-cycle debit was observed. Prior Cofrinho, financing-edit, insurance, Larissa-payment and rejected-boleto decisions remain intact.

## Material card defects established with real reader inputs

1. **Itaú Mastercard accessibility:** the current Flow description uses Personnalite, which the protected source's `isCardSettlement` predicate does not recognize. The existing inline invoice UI can therefore be unavailable despite imported detail.
2. **Due date versus cash date:** `lts_browser_card_settlement_detail_v2` returned `matched=false` for the actual scheduled-cash-date/name/amount input. The same invoice queried at its contractual due date returned `matched=true` with all 66 imported lines and zero difference. Fix the invoice linkage, preserving both dates; do not change the actual scheduled cash date or link a different cycle by proximity.
3. **Aeternum current open cycle:** the operational total is newer than its 64-line detail snapshot. The reconciliation view's zero delta only proves the old detail against the old total. The reader correctly cannot match that old detail to the newer amount. A newer PDF is already registered in private `source_documents` as `credit_card_invoice`, reference date 03/09; recover/reprocess it rather than telling the user it was never provided.
4. **C6 credit presentation:** the existing reader returns all eight current-cycle lines and the exact total. The unclassified reversal produces a negative pending-value aggregate. Display pending credit distinctly from unclassified spending; do not invent a category to hide the problem.
5. **Other Visa units:** an older Visa Infinite Prime PDF was recovered from the user's File Library. It does not establish the identity of the small generic September Bradesco debit. Current Visa Itaú detail was not validated. Keep banks, billing units and invoice cycles separate.

Reader tests used controlled authenticated PostgreSQL claims inside rolled-back transactions. They are not signed-in browser or physical-iPhone E2E. No database financial writes were made by those read tests.

## All-card presentation contract reaffirmed

The approved Visa Aeternum concept applies to ALL Bradesco, Itaú and C6 cards, not only Aeternum/C6 examples: inline summary in Flow, documentary status/total, confirmed LTS category names, descending category totals, explicit pending classification and access to complete documented invoice detail. Preserve merchant evidence, instrument identity and installment context. Do not substitute issuer categories for user-confirmed LTS rules, fabricate missing purchases, or count purchases and invoice cash settlement twice.

The existing closed-invoice branch orders categories descending, but the open-invoice branch uses a different presentation and lacks the same category summary/full-detail navigation. All-card parity remains OPEN. Earlier fixture parity PASS does not establish the actual consumer cases above.

## Next safe completion gates

- Resolve the blocked application through a permitted execution context; do not bypass the block or pretend the failed attempt changed the app.
- After a permitted application, read back all missing facts, exact replacement links, current bank close and historical continuity before new homologation.
- Fix and test card detection and contractual-date lookup with the real naming/date shapes, including explicit rejection of ambiguous bank/cycle matches.
- Restore the same invoice presentation for open/closed documented sources without overstating completeness; reprocess the already-registered newer Aeternum source.
- Preserve default D-5 through D+30, the protected source/public root, prior decisions and all master-backlog dependencies. Bulk classification remains unreleased. Dashboard remains out of scope pending its separate approved image.
