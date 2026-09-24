# V183 — monthly expense composition

## Preservation boundary

Based on main c74be6ea5c6756bb0db3d9ed61ebd5595de76b06, using a separate worktree so the previous workspace and its uncommitted work remain intact. Fixed V181, public root, financial facts and shared readers are unchanged.

Inspection corrected an outdated continuation assumption: the candidate's V179 fetch adapter already maps monthly balance calls to the V178 person-integrity reader. Do not replace that reader with V5 or rewrite classifications based solely on the literal RPC name in an earlier module. The old V175 internal reader has a window limitation, but current V176/V178 paths already bound the source; no shared database function was changed.

## Implementation

- Monthly expense group names, nonzero monthly values and period totals open the existing source-keyed V178 detail drawer.
- Partial boundary months clip to the selected custom interval, including leap years; credits remain negative rather than disappearing.
- Before opening, confirm current report ownership, group identity and amount. The existing drawer verifies pagination, unique rows, revision and displayed total.
- Aggregate-only invoices open their existing source group. No invented purchase or merchant-level coverage.
- Income matrices remain unchanged: an expense reader is not a valid income detail endpoint.
- Monthly completeness guard now rejects duplicate/out-of-window months, missing numbers and group matrices that do not reconcile to their monthly summaries.

## Local checks

35 JavaScript tests pass across monthly-detail, period-ownership and income-review suites; 30 historical coverage assertions and 8 Python reconciliation tests pass. Parser and git whitespace checks pass. All fixtures are synthetic.

Published authenticated validation and regression CI remain required. This extends V182-F10/F12; it does not close every expandable total, category correction, historical source or release gate. No complete-successor link or production promotion is authorized by this partial result.
