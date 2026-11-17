# Exact primary-input fingerprint reuse

The current review guard repeatedly serializes every row from nineteen primary
relations, including large collection and cache records. Preserve the complete
original guard JSON and every producer, view, trigger, owner, day and card check.
Reuse only the exact primary-row MD5 object after statement triggers prove none
of those inputs changed. No financial source value is cached differently.

Every primary relation receives an AFTER statement revision trigger covering
INSERT, UPDATE, DELETE and TRUNCATE, including replica-mode writes. The fast path verifies the frozen V464
profile, relation OIDs, full attribute/default/inheritance shapes, enabled trigger
definitions and catalog identities, pinned helper source and metadata, origin replication mode and the
original privileged execution role. Unknown or disabled contracts use the
unchanged full-row hashing loop. Financial epoch, owner, date, digest and exact
source keys are rechecked; source races remain errors. Cache writes use the
existing short-lock pattern and are omitted in read-only transactions.

Three new private metadata tables are inaccessible to browser/service roles.
Only the existing postgres-owned caller can reuse them. Existing guard ownership,
ACL, search path, volatility, authentication and timeouts remain unchanged.
Installation acquires the existing worker advisory lock and refuses an active
worker or a changed original definition. Trigger disable/enable cycles and table
rewrites cannot silently revalidate old hashes. Inherited relations are excluded
from reuse. Rollback
removes only the new metadata objects and restores the exact original guard.

Native PostgreSQL 17 tests use invented rows and a recognized fixture-profile
digest. They compare the installed guard against the complete original function
after DML, DDL, replication drift, corruption, rollback and concurrent commits.
They are distinct from authenticated live acceptance and physical-device tests.
