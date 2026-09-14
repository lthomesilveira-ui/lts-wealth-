# V162 — H12c household category and H13a vehicle-use classification applied

Date: 14/09/2026. The user approves the proposed household category for H12c and clarifies that H13a is a bin for the car. These two classification questions are resolved and must not be asked again.

## Classification actually saved
H12c uses the newly approved Casa - Utensílios e equipamentos category for the already-identified electrical-protection kit. H13a uses the original Carro rubric, recovered from the ledger, with Lixeira para carro recorded as item detail. The user authorized choosing an appropriate car-related line; selecting the existing broad vehicle category avoids inventing an accessory taxonomy or labeling an accessory as maintenance. No vehicle model or driver was assigned.

Only those two current open-invoice source lines and their decision provenance were changed. The source description, printed date, card identification, amount and installment fields remained untouched. There was no new expense or bank payment, no general category-equivalence mapping and no merchant-wide rule.

## Audit / tests
The owner-scoped source_documents audit key h12c_house_h13a_car_bin_confirmed_20260914_v1 retains exact user answers, source identity, original invoice/detail/review/account/catalog/product snapshots, the two applications and PASS assertions. The existing category-creation function added the one newly approved label. Stored product data was verified unchanged apart from category_options; no full summary refresh was attempted.

Checks passed for exactly two new classifications, unchanged raw fields, invoice totals/counts, unrelated categories and bank records, and an exact two-line reduction in direct pending review. A separate authenticated consumer-signature read after commit returned both categories and the same invoice total. This is controlled database-consumer verification, not an actual user-session/physical-phone E2E test.

## Remaining scope / continuity
Direct card pending now equals twelve. Seven are the already-answered H06/H08 sources still awaiting application; the five still needing evidence/context are H09b, H10a, H10b/c and H13b. The two prior bank reimbursement answers are also unapplied, not questions. Stored Updates summary remains forty card lines and eleven bank groups; no claim of screen-wide synchronization or full migration completion.

This new accepted operation does not retry, disguise or bypass the previously denied naming, seven-answer, bank-transfer or summary-refresh actions. H12a remains in the child structure/equipment category; verified H12b/d toys retain their current name until an allowed shorter-label application. The obsolete ten-item rename plan must not absorb H12c or H12a.

All earlier evidence archives, historical/source reconciliation defects, vehicle consumption-report gate, payment/control markers, beneficiary display, actual-session/manual-release gates and other-card documentary gaps remain binding. V162 frontend, manifest and protected index are unchanged. The future equivalence-map plan remains deferred. Resume via RETOMAR_LTS_WEALTH.md, updated execution state, this checkpoint and the complete preserved backlog/decision documents.
