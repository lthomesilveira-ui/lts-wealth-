# Wait for the existing reviewed snapshot

The review reader previously rebuilt historical classifications while the
existing product worker was pending or running. That duplicate foreground work
competed with the worker and could expire before a complete snapshot existed.

For the same owner with a genuinely outstanding pending/running request, return
SQLSTATE `55000` before starting the expensive review. The published V454 read
transport already recognizes this precise not-ready state and observes the
existing job. This creates no job and returns neither zero nor stale rows.

Every source guard, digest, row, null, duplicate, fallback and permission remains
unchanged when the reader can run. The existing worker also invokes the browser
review reader indirectly during its operational refresh before publication.
That path is allowed only when the private claim matches the same owner's
current token, claimed version and claimed epoch. Its final warm after the
transaction-local ready update also remains readable. Failed or missing requests
and other owners do not trigger the busy condition.

Native PostgreSQL 17 tests compare exact original/replacement ready rows,
reproduce duplicate work before the patch, check pending/running errors without
false empties, the indirect claimed-worker read before publication, rejection of
wrong or stale claims, worker readiness within the same transaction, source races,
digest/range invalidation, read-only behavior, access, metadata and rollback.
All fixtures are synthetic. Full application performance requires live acceptance.
