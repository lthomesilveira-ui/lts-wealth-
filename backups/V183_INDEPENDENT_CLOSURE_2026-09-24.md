# V183 independent technical closure

## Isolation

Only the V183 candidate loads the added modules and the upload-safe V168 copy.
The protected index, fixed V181 manifest, original V168 module and financial source rows are unchanged.

## Implemented

1. Award schedule headline equals its own recorded rows, not the documentary snapshot. Original quantity/date/price/cash facts are never rewritten by the provenance reader. Unknown quote dates are explicit; import/update timestamps are not market timestamps. Model quantities are not promoted to the current statement's quantities.
2. Authenticated, private-schema provenance endpoint; public wrapper is SECURITY INVOKER, anonymous access revoked. Successful explicit quote/date edits invalidate provenance and refresh the existing dashboard reader. Failures never cause an automatic financial write.
3. Current invoices expose separately documented payment status and cash-date differences. A reconciled invoice or complete purchase list is not proof of bank debit. Unknown bank/cycle/read failure remains unverified.
4. Bank-statement upload captures association before asynchronous work, blocks double submission, validates date/bank/size, requires a returned registration protocol and never deletes an uploaded object because registration confirmation was lost. Post-registration refresh failure preserves success. Uncertain registration requires queue inspection before resubmission.

## Verification

- `test-v183-award-provenance.cjs`: 8 tests.
- `test-v183-card-payment-status.cjs`: 6 tests.
- `test-v183-upload-safety.cjs`: 8 tests, including timeout, double click and refresh failure.
- `test-v183-award-provenance.sql`: 13 assertions, authenticated role, rollback of all test writes; tests global/individual assumptions, tax reserve, provenance readback, unchanged statement/bank facts/quantities/original dates and anonymous denial.
- Existing period, search, history, receipt and flow tests must remain green.

No claim of real-device acceptance, all-history documentary certification or production promotion follows from these tests. Private live QA and publication evidence are recorded separately.
