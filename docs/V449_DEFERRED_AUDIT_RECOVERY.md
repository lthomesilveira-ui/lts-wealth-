# Deferred audit recovery on the accepted V448 chart

A late source change can withdraw the server's audit snapshot after initial product boot. The audit's bounded request then fails while the product controller still reports its earlier snapshot as ready. This candidate observes that failure, checks the existing server job and installs a verified complete product before the existing screen consumers resume.

Recovery is coalesced and limited to two attempts per server request version. It joins active status or product reads before checking again, survives a same-version readiness confirmation and is cancelled across session changes. It never requests a refresh job, repeats a financial write, retries authentication, relaxes source guards, raises timeouts or hides a permanent failure.

V448 remains byte-preserved, including its accepted expense-chart CSS. The release contract compares every inherited asset; only the transport (standalone and the actual startup bundle), recovery controller, release badge and provenance differ. It verifies that every other byte of the startup bundle is unchanged. Tests exercise late failures, bursts, active reads, permanent failures, session cancellation and authentication, plus the inherited protocol tests and rendered Chromium/WebKit flows.

Synthetic validation, served candidate, authenticated acceptance and canonical promotion remain separate. PERF-N requires a measured complete opening and filter changes with real data; these tests alone do not close it. Physical iPhone acceptance is separate.
