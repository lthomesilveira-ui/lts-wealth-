# Review admission and confirmed FGTS caption

An expense review can wait behind a valid long-running financial read. Its
previous 22-second wall timer discarded the eventual successful response, even
when that request itself completed promptly. The V433 reader uses the existing
transport's bounded admission. Its active execution budget stays at 22 seconds;
the transport's existing admission bound stays at 60 seconds. Other reads,
authentication, caches and all mutation submission paths are preserved.

Each review response is checked against the current session, request, search,
pagination and the existing response contract. A superseded response cannot
replace a newer list. An unavailable list remains unknown; a failed refresh of
a known list retains its rows and a concise visible warning with a retry.

The Flow caption identifies an FGTS redemption only when the existing event
already carries both the asset-movement flag and an exact FGTS category or
description. Other own-account transfers retain their existing labels.

`build.py` verifies every V425 asset before creating the new release and builds
the same bytes on replay. Published predecessors are never modified. Lifecycle
tests reproduce the former lost response and cover superseded searches,
session changes, malformed responses, retry, mutation timeout preservation and
negative caption cases. The complete mocked app is rendered in Chromium and
WebKit at mobile and desktop widths, with financial-response parity, unknown
and failure states, pending payments, disclosures and overflow assertions.

These synthetic results are distinct from publication, real authenticated
verification and physical-device acceptance. They do not certify whole-app
latency or close unrelated database, recovery or source-document work.
