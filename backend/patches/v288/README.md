# V288 backend candidate — NOT APPLIED

This is an execution-only prototype, not a public application release or a
production migration. The default script ends in ROLLBACK. V285 is unchanged.

The invoice-planning query reuses one materialized C6 identity set instead of
calling the same stable helper twice. The cycle query reuses one materialized
document-match set at four expression sites. Matching predicates, monetary and
date policies, source identities, output columns, function owners and grants are
unchanged. A trailing separator preserves aliases originally adjacent to `)`.

An actual private component trial compared complete cycle JSON (excluding only
its root calculation clock) and every planning row. Both were exactly equal.
The observed component timings were 2169.832 → 1340.781 ms for cycles and
3047.769 → 1947.696 ms for planning. These are not application-cold or device
latency guarantees. The first prototype lacked one alias separator; it failed
and rolled back before the corrected component trial passed.

Complete product parity attempts did not produce acceptance receipts: the
connector returned Invalid or expired requestState. Catalog checks confirmed the
original definitions remained installed and no abandoned probe held locks.
Do not reinterpret those errors as completed tests or silently remove guards.

Authenticated V285 review also found an existing review-queue timeout. A private
source query exceeded the authenticated role's 8-second statement limit; this
prototype alone does not establish that the queue will meet that limit. The role
limit was not changed and the failing screen is not accepted.

Before any installation: complete the missing whole-consumer parity and negative
cases, recheck source and privilege leases, repeat the transactional application
proof, and record a bounded official migration with its private receipt. Never
turn this default rollback script into an installer by simply removing ROLLBACK.
Real identities, financial inputs and private trial receipts are intentionally
excluded from this repository package.
