# Unique classification counts

A purchase can be pending in both the general expense queue and the card queue before the invoice month begins. The overlap calculation incorrectly skipped that future invoice month, so navigation counted the same source twice.

Always determine overlap by the existing owner, source table and source reference within the purchase period. Keep every card row available; only the additional-count field excludes entries already represented by the expense queue. Search and pagination retain full counts. No financial row or category is written.

Native PostgreSQL CI exercises the actual wrapper with future invoice months, shared source identities, separate owners, search, pagination, empty periods, unchanged source tables and replay. The patch leases the old function body and preserves signature, ACL and security attributes.
