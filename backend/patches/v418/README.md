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

These files are a guarded deployment candidate. The native CI covers the reader contract, real builder capture, worker fallback,
reuse and function metadata. Interleaving tests pause after summary calculation
and cover invalidation, request coalescing, changed epochs/card receipts and
connection loss with rollback of the previous product and summary. Acceptance
still requires passing results for the final commit, representative performance
and installation verification.
No installation or new scheduler is included in this draft.

Compose the atomic package with `python3 backend/tools/projection_summary_v418/package.py`.
It verifies exact predecessors and preserved execution metadata, refuses an active
worker, and requests the existing queue without clearing caches or changing cron.
After installation, verify the registered migration and next natural publication,
summary guards/content, unchanged source profiles and representative read cost.
A successful administrative read is not a real authenticated HTTP journey.
Existing published interface releases are outside this change.
