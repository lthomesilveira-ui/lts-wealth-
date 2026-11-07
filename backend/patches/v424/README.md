# V424 current-month card budget

An opt-in planning rule uses only known card-cycle obligations for due dates in the current calendar month. Future due months retain the existing scoped estimates. The current month follows the calculation date already resolved in the project time zone, so the boundary advances automatically at month and year rollover. The source of truth is the due date, not the original purchase date or the UI's selected range.

The rule is activated only by a private owner policy field `current_month_card_budget: known_only`. No private values, identities, approvals or source records belong in this repository. Without that field, the previous behavior is identical. Invalid explicit values are rejected. Closed/paid/cancelled cycle precedence and incomplete-source guards remain first. Missing data is not replaced with zero. Current known installments and ordinary purchases remain; only newly generated current-month budget supplements are omitted. All future scoped allowances, legacy installments and other recurring series are preserved.

The patch modifies one existing pure calculation function, guards the exact predecessor and preserves ownership, grants and every non-source attribute. Replay is idempotent. It does not activate a policy, write financial events, alter bills, change schedules, raise API limits or modify a published release. Production activation, source equality, exact current-month delta, future-event parity and natural cache refresh must be verified separately.

Tests install the reviewed PG17 predecessor and run existing projection/scoped-budget checks plus current-month, boundary, leap-year, missing/closed/cancelled, noncard and opt-in cases. Synthetic tests are not a private-session or physical-device acceptance.
