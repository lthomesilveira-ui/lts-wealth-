# Shared current actions

Dashboard and Actions previously used separate audit slots. A refreshed audit in
Actions did not update the Dashboard count. Cached card tasks also referenced an
older invoice snapshot, despite the current card reader showing newer purchases
and an owner-confirmed due rule.

V333 derives both views from the same audit and canonical card cycles. It replaces
legacy card tasks with one nearby, unreceived cycle per card, uses its current
known amount and due date, and opens that exact composition. Received invoices
and confirmed settlements do not become missing-total requests. Undated and
incomplete cycles retain their uncertainty. No invoice, forecast or transaction
is created or changed. The counter is unavailable while either source is missing;
a failed read keeps its warning and retry action instead of implying zero work.

The audit read checks its session generation and token before applying a response.
Sign-in and sign-out invalidate its captured state. The published V312 and earlier
releases are unchanged. V333 adds no endpoint, grant, migration or paid service.

Validation includes immutable asset hashes, read-only model cases, and the actual
release stack at desktop, 390px and 360px. Browser fixtures exercise delayed audit,
cross-route count consistency, refreshed card values/due dates, exact detail
navigation, unavailable reads and recovery, Flow interaction and page width.
Synthetic browser checks are not a physical iPhone or private-session certificate.
