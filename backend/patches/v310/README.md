# Reuse existing contract payment identities

The dated V309 contract reader only checked the realized-event registry. It
missed payments already reconciled through the earlier documentary matcher,
leaving valid installments in its unconfirmed list.

The private V310 selector validates the existing exact owner-confirmed binding,
its unchanged raw source hash, bank/account ownership, contract number, numbered
installment, full term, actual amount/date and bank-position coverage. That
unambiguous bank contract identity also recognizes other exact numbered
installments of the same contract. It does not use amount/date/name similarity
or create an owner confirmation. Pending, deleted, foreign, conflicting and
future payments cannot become paid installments.

The dated reader merges this path with the existing realized-event validator.
Both paths to one physical bank debit count once; ambiguous claims are rejected.
Original scheduled dates and actual payment dates remain separate. An invalid
installment integer cannot abort the whole reader.

The migration leases the exact prior definition and dependencies and preserves
the reader's OID, ownership, ACL, configuration and invoker status. One new stable
invoker helper has an empty search path and no anonymous/authenticated execute
grant. No financial source, original projection, bank record or balance changes.
The published V309 interface consumes the corrected response unchanged.

PostgreSQL 17 CI reruns the V309 suite, checks 49 rejected documentary proofs,
the mortgage evidence cases, earlier exact installments, deduplication, original
attributes, replay and two drift rejections. A browser then renders the native
PostgreSQL fixture response through the actual immutable V309 stack at desktop,
390 px and 360 px. These synthetic checks do not certify a private production
HTTP session, a physical device or a complete recovery.

`lts_v310_wealth_cold_rollback.sql` is a separate real-reader probe with an 8s
limit per call. It invalidates private memo metadata inside ROLLBACK, compares the
complete cold/repeat financial payload excluding only the consultation timestamp,
and performs no financial source DML.
