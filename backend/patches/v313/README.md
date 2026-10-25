# One operational read for pending projections

The pending-projection query joined bank anchors directly to a volatile,
expensive operational reader. Its actual plan invoked that reader three times
for three anchors. Materializing its result before expanding the event array
limits the shared read to once. No-anchor reads skip it entirely.

The narrow transformation preserves every existing payroll, FGTS, documentary,
bank and settled-invoice condition and the final classification and ordering.
Definition leases reject unrelated drift. OID, owner, ACL and every other
`pg_proc` attribute are checked after replacement; deployment is idempotent.
There are no new functions, grants, source writes or UI changes.

PostgreSQL 17 runs the actual original and transformed pending query over bounded
synthetic dependencies. Cases retain nonempty pending sets, settled receipts,
changed source hashes, one/no anchors and another owner, and count operational
invocations. This is not a full database/Storage restore or production HTTP test.
Real source parity and cold public Flow checks are separate deployment evidence.
