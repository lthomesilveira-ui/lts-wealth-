# Preserve an existing received invoice on its due date

The current-day reconciliation path removed a received invoice forecast when its due date arrived. Its source remained present in the base engine and monthly summary, but vanished from projected daily cash and funding suggestions.

The patch retains the existing negative event only when one official received invoice matches its owner, cycle identity, bank, date and exact amount, the invoice has no reported payment and the existing settlement reader has no settlement evidence. It marks the event as an unposted current projection. The existing reconciliation excludes that flag from posted cash while carrying it into the operational closing. No event, payment, category, invoice, source date or amount is created or edited. Partial-payment amounts remain unresolved rather than inventing a remaining balance.

Both live read paths are patched: the browser path and the warming worker's cache path. The worker path also adopts the native array assembly already used in the accepted browser path, preserving every day and field while avoiding repeated copying of a growing JSON array. This is an assembly optimization, not an expanded forecast horizon.

The installer and rollback guard exact live definitions, ACLs, ownership, security mode, search path and timeouts. They are atomic and idempotent, and reject concurrent edits. They do not invalidate caches, run workers or send notifications; those are separate coordinated operations after installation.

Native PostgreSQL17 tests compile both full definitions and execute their exact extracted current-day SQL blocks against invented source-helper fixtures. They cover unpaid, pending, posted, paid, partial, missing, ambiguous, cross-owner, wrong-bank, amount/date mismatch and existing authored projections. Full source tables are hashed before/after. Native array tests compare empty through 1,872-day outputs byte-for-byte, including nulls. This is not a complete production restore or physical IOPS measurement. Authenticated real-data and alert validation remain separate acceptance gates.
