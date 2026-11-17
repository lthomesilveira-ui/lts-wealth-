# Keep the documented series identity

The realized-source reader previously required the schedule's contract key to
occur literally in the bank description. A documented vehicle series uses a
stable internal key; its bank contract number is distinct. Replacing the series
key with the bank number loses that installment from the 60-part series reader.

Recognize the stable series only when the existing guarded V310 reader proves
the exact owner, payment source, numbered installment, date and amount. Require
the event's source/hash metadata and the realization receipt's bank contract,
installment and raw hash to match too. Every previous outer guard and existing
numeric-contract/partial-payment branch remains. Re-pin only this function in
the frozen review profile; refuse dependency drift, active work or metadata
changes. Neither this installer nor its rollback writes financial rows.
Rollback refuses to remove support while a realized stable-series record uses
it; review or reverse that data through its recorded evidence first.

Native PostgreSQL tests use the actual V310 proof reader with synthetic tables
and an independently confirmed anchor. They cover exact rows, missing/ambiguous
proof, each source guard, owner isolation, metadata, profile pin, drift and
rollback. Private reconciliation and real account acceptance are separate.
