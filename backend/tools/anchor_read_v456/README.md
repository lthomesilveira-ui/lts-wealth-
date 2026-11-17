# Read a valid liquidity anchor without taking a write lock

The dashboard calls the canonical anchor even when it is already current. The
predecessor takes `FOR UPDATE` before checking both source and payload keys, so
an otherwise read-only cache hit waits behind the product refresh transaction.

Read the committed row and perform the existing exact fingerprint check first.
Only a miss acquires the original write lock, then rereads and checks both keys
again before the unchanged full rebuild. A stale or missing result is never
accepted merely because another writer is busy. Financial sources, calculations,
errors, source checks, access rights, source-read deadlines and V454 assets stay
unchanged. Guarded installation and rollback preserve all function metadata and
reject a divergent predecessor.

The PostgreSQL 17 workflow reproduces the original current-hit lock timeout with
two real sessions. It checks nonblocking valid hits, exact complete miss output,
post-lock recheck, stale/missing errors, read-only behavior, private access,
metadata, rollback and drift rejection using synthetic fixtures only.
This scoped correction does not certify complete application performance.
