# Bank collection handoff

V458 changes the frontend refresh handoff only. Bank collection checks the
existing product controller before resetting complete-report readers. While
the existing job is pending or running, its controller retains responsibility
for the verified product and subsequent heavy-reader invalidation. The cash
reader remains independent. Without an active controller, the prior path is
preserved. A status poll that installs a product already owns invalidation.

Deferred readers join a known pending/running job without consuming the two
full-product recovery attempts. The existing timer, 20-status-poll ceiling,
ready-version retry limit, authentication handling and failed-job action remain.
No writer is replayed. Financial functions, source checks, HTTP/SQL deadlines,
authorization and the single-heavy-reader transport are unchanged.

The exact bank-collection enqueue RPC remains a native, uncached, unreplayed
write. Enqueue acceptance no longer clears verified reports; completion joins
the product controller above. Other mutations retain their invalidation rules.

Build using `python3 backend/tools/bank_handoff_v458/build.py`; verify with
`--check`. The public tests use invented data only. Native-device acceptance,
real session observations and source documents are recorded privately.
