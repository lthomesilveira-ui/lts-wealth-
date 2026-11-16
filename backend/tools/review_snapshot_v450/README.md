# Pending-review snapshot

The classification queue rebuilt the entire expense history for every count and
page. A slow source read could exceed its existing HTTP budget and leave the
classification notice unavailable.

This change reuses only the pending rows produced by the existing reader.
Paging, search, questions, suggestions, projection review and classifications
remain in the original endpoint. The existing claimed product worker warms the
same snapshot after all product and queue publication updates, in the same
transaction. It creates no additional job or identity and performs no financial
or source writes. The current mobile release remains unchanged.

Reuse requires the exact owner, calendar day, range, source epoch, receipt key,
reviewed producer and view definitions, invalidation-trigger definitions and
enabled states, and hashes of primary inputs outside the epoch guard. A digest
protects the saved rows. Missing or changed inputs rebuild using the original
reader; an unknown producer disables reuse. Source changes during a read fail
with a retryable conflict. Missing data never becomes an empty result.

The installer checks both live function definitions and their owner, ACL,
security mode and configuration before an atomic change. Existing private
helpers also have source and metadata guards. Rollback restores the callers and
keeps derived evidence. Anonymous/authenticated callers cannot invoke the new
private helpers directly; the existing endpoint retains its owner assertion.

Native PostgreSQL17 fixtures check exact queue parity, duplicate and decimal
preservation, pagination/search, owner separation, changes to epoch, receipts
and untracked inputs, corrupted snapshots, concurrent source/producer changes,
private-helper ACLs and guarded lifecycle. These fixtures do not certify a real
second identity or a full database/storage restoration. Real published-session
measurements remain a separate acceptance requirement.
