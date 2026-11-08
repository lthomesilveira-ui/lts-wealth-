# Optional memo writes

A reader can finish calculating its financial rows and then wait on a derived
cache entry held by another transaction. V430 makes only that final write
optional: same-key writers use a transaction advisory lock, and an independent
row lock gets at most 100 milliseconds before the memo is skipped. The computed
rows still return. Other database failures continue to propagate.

The three existing readers retain their source queries, source-change checks,
five-minute freshness limit, range slicing, ordering, OIDs, owners, ACLs and
function settings. No source, financial event, classification, receipt or
balance is modified. The helper is in a private schema and is executable only
by the existing service role and its owner.

The PostgreSQL 17 workflow checks output equality, attributes, replay,
read-only behavior, source-generation invalidation, setting restoration and
predecessor rejection. A two-connection test holds each cache row and requires
the corresponding reader to return the correct synthetic financial result
before the lock is released. This proves only the cache-contention repair;
cold source computation and whole-app performance require separate measurement.
