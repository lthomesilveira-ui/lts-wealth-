# Dated card new-spend provision

An optional owner-confirmed `new_spend_provision` replaces a card's historical/scoped budget from a specified month. The derived event is the fixed new-spend amount. Existing operational obligations remain in the baseline. Closed, paid, cancelled and incomplete periods preserve their existing precedence. Unidentified legacy estimates are flagged rather than combined with the provision.

This generic migration contains no private policy seed. It changes only the calculator, policy validation and dated scope handling; the optimized V438 builder remains unchanged. The private policy seed must preserve the policy activation timestamp, guard its prior value, record the exact owner evidence and invalidate derived reads.

`guarded_candidate.sql` is the migration body. `rollback-code.sql` restores the captured predecessors after drift checks. Roll back private policy before restoring code. No financial source rows are changed or deleted.

Tests under `backend/qa/v439` use invented amounts, synthetic identities and source adapters. The local PGlite suite covers calculator/build behavior, replay and rollback; it does not certify current authenticated data or browser rendering.
