# Prepared projection premises

The browser premises reader currently invokes the complete projection builder.
This candidate retains the already calculated summary during the existing
guarded product refresh and reads it only for the same owner, day, completed
request, source epoch, card fingerprint, policy and reference.

The builder captures an available result inside the worker transaction. If
lower readers reused flow data without running the builder, the worker prepares
the missing summary before taking publication locks. A failed or superseded
refresh rolls the summary back with the product. The browser never invokes the
heavy builder and reports unavailable premises when the prepared result is stale.

These files are a draft deployment candidate. The native CI covers the reader contract, real builder capture, worker fallback,
reuse and function metadata. Interleaving tests pause after summary calculation
and cover invalidation, request coalescing, changed epochs/card receipts and
connection loss with rollback of the previous product and summary. Acceptance
still requires passing results for the final commit, representative performance
and installation verification.
No installation or new scheduler is included in this draft.

Apply guard.sql, capture.sql and read.sql atomically only after acceptance.
Existing published interface releases are outside this change.
