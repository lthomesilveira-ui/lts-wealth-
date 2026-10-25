# Independent reads during memo contention

Concurrent expense requests could wait on the same derived operational-key memo
until their lock or statement timeout expired. A successful SQL read in isolation
did not demonstrate that the signed-in application's parallel reads would work.

Keep the same source-key calculation, revision check, freshness and caller access.
Only one cooperating request attempts the memo write. Other requests return their
computed key immediately. An unrelated memo-row lock is bounded to 100ms, or the
caller's stricter limit, and a cache lock failure does not fail the financial read.
The caller's lock timeout is restored. Other failures remain errors.

The leased replacement preserves the existing function identity and security
attributes. It adds no endpoint, grant, financial write, source change or global
timeout. No cache revision change is necessary because the returned key is equal.

PostgreSQL concurrency fixtures reproduce the previous timeout and verify cache
hits, blocked rows, cooperating readers, read-only transactions, source drift,
replay, strict lock limits and unchanged financial fixtures. Existing classification
and desktop/mobile regressions remain separate from the real private-session check.
