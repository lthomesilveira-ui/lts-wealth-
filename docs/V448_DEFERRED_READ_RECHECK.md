# V448: resume verification after a deferred projection failure

Actual V447 opening recovered its completed product automatically. Subsequent
projection reads still encountered 8-second server timeouts after ingestion had
changed the guarded card source and another existing refresh job was running.
The opening controller had already stopped at the preceding ready version.

A transient 5xx projection-audit response now signals that controller to check
the existing job. Checks coalesce and retain its existing polling limits. A new
completed version is installed once and the existing ready event resumes screen
readers. No refresh-request endpoint is called by this signal, and neither
financial sources, writers, guards nor authentication/deadlines change. The
original failure remains visible until an actual successful response replaces it.

HTTP failure to pending status to a complete product is exercised with the real
transport and controller in rendered Chromium/WebKit mobile and desktop cases.
Those invented-data results do not certify real authenticated performance.
Canonical entry stays V442 until actual acceptance.
