# Matched bank expense recovery candidate

## Defect and scope
A bank posting matched to a current operational obligation is removed from the new-bank reader. If its economic expense is absent from the historical expense base, that removal becomes an omission rather than deduplication. Cash and consumption can legitimately differ, but a matched ordinary debit must not disappear from consumption.

The new helper copies the bank/owner-transfer eligibility boundaries, requires exactly one explicit reconciliation candidate with the same source identity, bank, date and amount, rejects ambiguous matches and existing economic representations, and reuses the ordinary expense classification and card-settlement exclusion downstream. Only the expense baseline gets the additional rows. The shared Flow reader stays unchanged.

## Implemented
- Expense-only SQL helper and guarded integration into existing baseline.
- Idempotent install guard rejects a concurrently changed baseline.
- Helper is not an anonymous/authenticated public endpoint.
- No changes to financial source rows, canonical release pointer, V442 or V444.

## Verification
- The actual helper SELECT was evaluated read-only against existing owner sources: recovered only the five currently missing exact-linked debits. Private values and screenshots remain outside this repository.
- Pure candidate contract: 31 synthetic assertions for identity/date/amount, pending and deleted sources, transfers, assets, invoices, ambiguity, existing representation, no input mutation and repeat deduplication. Run node backend/tools/expense_match_v445/reconcile.test.cjs.
- The JS contract is NOT a test of installed SQL. Full SQL installation/rollback rehearsal, multi-period conservation checks, fingerprint refresh, protected real-session checks and independent review remain gates.

## NOT installed or published
Do not execute install.sql merely because this draft exists. First review helper equivalence and account boundaries, rehearse transactionally in an approved environment, verify pre-existing rows unchanged and no card/transfer duplication, and version expense read fingerprints without deleting source or cache data. Then install through the established deployment workflow and verify both screens with authenticated owner session.

The mobile graph collision is a separate UI defect; no unrendered CSS fix is included here.
