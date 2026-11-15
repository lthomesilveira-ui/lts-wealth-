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
- The actual helper SELECT was evaluated read-only against existing owner sources: recovered five missing exact-linked debits in the current month and two in the preceding month. The integrated baseline SELECT preserved all existing rows, added only those seven identities, and preserved beneficiary/property classification. Annual recovery and the union of monthly recovery matched exactly (zero differences). Private values and screenshots remain outside this repository.
- Pure candidate contract: 31 synthetic assertions for identity/date/amount, pending and deleted sources, transfers, assets, invoices, ambiguity, existing representation, no input mutation and repeat deduplication. Run node backend/tools/expense_match_v445/reconcile.test.cjs.
- The JS contract is NOT a test of installed SQL. An independent review corrected cross-period identity checks, partial-integration guards and cache invalidation on installer reruns.
- `test_installer.py` executes the exact helper and installer against a new disposable PostgreSQL 17 cluster with invented data. Only the expected baseline hash is substituted for the synthetic baseline. It tests first install, rerun, permissions, rollback and guard failures without connecting to production. The dedicated GitHub workflow uses a standard public-repository runner, no production secrets and no artifact uploads.
- A single read-only annual performance sample was approximately 3.93 seconds for the inline candidate versus 1.72 seconds for the original baseline; this is not a benchmark and latency remains a review gate.
- CI success, final-reader integration, authenticated owner UI validation and deployment remain separate gates. None is implied by SELECT-level checks.

## NOT installed or published
Do not execute install.sql merely because this draft exists. First review helper equivalence and account boundaries, rehearse transactionally in an approved environment, verify pre-existing rows unchanged and no card/transfer duplication, and version expense read fingerprints without deleting source or cache data. Then install through the established deployment workflow and verify both screens with authenticated owner session.

The mobile graph collision is a separate UI defect; no unrendered CSS fix is included here.
