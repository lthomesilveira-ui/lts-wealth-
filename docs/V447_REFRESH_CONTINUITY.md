# V447: preserve readiness verification

Two controller regressions were reproduced on the actual V446 module. Temporary
cache invalidation could mark an already fetched job pending; its subsequent
ready status was rejected as a repeated fetch even though a new complete result
needed verification. A coalesced poll during installation of a newer unavailable
snapshot could also erase its next scheduled lightweight check.

V447 clears completed-fetch identity when readiness is withdrawn and preserves
timers when joining active checks. It fetches a confirmed complete product once,
keeps contradictory/malformed responses actionable, and retains authentication,
deadlines, poll/recovery caps and the no-mutation recovery contract.

A diagnostic attribute contains only phase, error kind and attempt count; no
credentials, owner IDs or financial figures are added to diagnostics or report copy.
The candidate inherits V444–V446 read cancellation, aligned horizon and queue
recovery. Both new tests fail on V446 and pass on V447; all prior controller,
transport and opening safety contracts are repeated against the relevant artifacts.
Rendered same-version recovery and unchanged fictional financial content are
checked in Chromium/WebKit on desktop/mobile. Canonical acceptance still requires
actual authenticated measurements; the entry remains V442 before that gate.
