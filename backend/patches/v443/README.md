# Dated resource requirements and reviewed payroll receipts

The existing reminder assigned an account's entire future trough to the deadline before its first negative day. This patch covers the incremental shortfall at each date and keeps the original first-negative and worst-balance metrics separate. Repeated negative days do not duplicate an unfunded requirement. Suggested transfers and redemptions remain conditional and never execute a financial transaction.

A second correction lets the projection builder recognize an explicitly reviewed salary receipt already included in the documented checking balance. A private receipt links one owner, payroll occurrence, transaction identity and hash, bank account and balance anchor. Pending, deleted, changed, cross-owner or unanchored evidence cannot suppress an occurrence. No other payroll month, thirteenth salary, existing installment or card policy is changed.

Apply the evidence table/helper before the guarded builder patch. Receipt evidence is private and is not seeded by this repository. Changes to that evidence invalidate the existing derived reads through the existing worker. Function owners, security attributes and existing grants are preserved; the new table uses RLS and has no browser grants.

Validation separates synthetic PostgreSQL regression tests, a real-data rollback rehearsal and authenticated browser acceptance. The first two do not certify the browser or authorize release promotion. Preserve PR322, PR323, the immutable V441 release and the existing protected preview. No production pointer is changed by these files.

No new service, job, transfer, payment, source import or notification send is introduced.
