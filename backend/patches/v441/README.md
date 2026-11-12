# Canonical category budgets

This migration adds planning preferences and two authenticated RPCs. It does not change the financial ledger, card obligations, income classifications, projection policy, cache epoch or existing refresh workers. The guard refuses to overwrite an implementation already present.

Actual expenses use `lts_v229_expense_rows` by competence, including explicitly identified pending purchases. Actual income uses `lts_income_private.rows_v296`; only regular salary categories without bonus, vacation or thirteenth-salary descriptions enter the salary reference. Bonus and all other extraordinary receipts remain separate actuals. Card invoice payments and projected card provisions are never added to category consumption.

Initial proposed category goals use the previous six closed months, with missing coverage kept unknown. The salary reference is the median of the latest three closed months with regular salary. These references repeat across the selected year's twelve months and are labeled proposals, rather than past owner-approved budgets. Monthly or full-year edits affect planning preferences only, use row locking and expected revisions, and preserve an audit trail. No owner targets are seeded by deployment.

Validation includes independent canonical-total comparison on the current database, source-backed income checks, PGlite isolation and revision scenarios, actual transport admission tests and full-app browser checks. Private results are stored outside the public repository.

Rollout requires the migration before V441 UI promotion. On a UI regression, restore the previously validated loader pointer and preserve the new planning table and audit history. No historical financial rows need to be deleted or restored.
