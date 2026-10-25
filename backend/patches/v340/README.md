# Pending income query work

The income review queue previously calculated source hashes and review tokens for
every receipt before discarding classified receipts. Under the existing reader
budget, that unnecessary work could contribute to a failed refresh.

`income_review_work.sql` derives a private review worker from an exact leased
definition of the existing full-income worker. It keeps all source, ownership,
date, cash, classification and matching rules. It deduplicates with the original
winner order, then selects pending categories before calculating review metadata.
Filtering before deduplication could wrongly resurrect a losing pending duplicate;
the native fixture covers both a classified winner and a pending winner.

Only the private queue's worker call changes. The full-income worker, public API,
queue search, ordering, pagination, tokens, owner checks and caller privileges are
preserved. The new worker is invoker-only with an empty search path and the same
time zone; only the service role and its owner can execute it directly. There are
no source writes, cache invalidations, timeout increases or retry changes.

The migration rejects changed worker/queue definitions and conflicting existing
workers. Replaying an identical patch preserves the definitions. Apply through the
migration mechanism after the native PostgreSQL 17 workflow passes.

The CI fixture uses synthetic dependencies and owners. It compares complete queue
JSON for nonempty/empty results, pending category spellings, duplicate winners,
search and pagination, editable/uneditable identities, raw-source hashes and
decision tokens; it also checks invalid inputs, role access, source preservation
and function attributes. It does not certify production login or real HTTP
isolation. Production validation must separately compare read-only results under
the existing timeout and open the actual owner session.

This patch addresses income review work. Expense-review timeouts and card
source-revision changes are separate unresolved observations.
