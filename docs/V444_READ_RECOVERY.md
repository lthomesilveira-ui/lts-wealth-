# V444: superseded reads and transient recovery

A product refresh cleared query maps while obsolete readers continued occupying
the shared admission queue. A transient status or product failure then stopped
verification even when the server job subsequently completed. The published app
reproduced long admission waits and an actionable update failure.

V444 cancels superseded queued and active readers before the replacement product
is admitted. It retains one expensive read at a time, existing query deadlines,
collection holds, authenticated deduplication, and bounded admission. Diagnostics
separate queue time from execution time, including a queue expiry.

Transient status/product failures receive at most two automatic recovery attempts
after 10 and 20 seconds. Each verifies lightweight status before fetching a
complete product. Authentication failures, invalid envelopes, contradictory ready
responses and failed server jobs retain their existing recovery paths. No new
server job or financial mutation is requested by automatic recovery.

The V442 assets, financial readers/writers, source guards, projection policy,
budget calculations and financial copy remain unchanged. The new immutable
release is initially a candidate; adding its assets does not promote the mobile
entry. Canonical promotion requires rendered candidate verification and actual
authenticated load/filter measurements. Synthetic fixtures do not certify a
private session, physical iPhone, backend capacity, or full historical audit.

Validation includes deterministic asset hashes; cancellation, deduplication,
collection and deadline contracts; protocol/authentication regressions; rendered
pending, failed, complete and expanded states at desktop/mobile sizes. Private
financial observations and screenshots remain outside this repository.
