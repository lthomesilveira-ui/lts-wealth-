# V305: exact-source health-reimbursement confirmation

Use the existing authenticated expense-review writer for the owner's explicit
confirmation. A private manifest pins source ID/hash/type/date/amount/currency/
institution. The operation uses the existing health-reimbursement category;
it neither infers a beneficiary from the recipient nor generalizes the decision
to other payments or creates a new rule.

Live rollback tests cover the confirmed row, exact source/event/category and
other-decision hashes, every other canonical expense, unchanged total amounts
and bank cash, ten rejected mismatched manifests and idempotent reapplication.
The operation records the owner's exact statement in one source-specific audit
receipt. These are SQL-role tests, not private browser-session certification.

`backend/operations/confirm_health_reimbursement_v305.sql` reads
`lts.v305.input`; the caller owns its transaction. Never commit private
manifests or source identifiers with this generic code.
