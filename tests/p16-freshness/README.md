# Synthetic Open Finance timestamp contract tests

This package contains generic SQL definitions and synthetic fixtures only. No production IDs, metadata payloads, financial values, receipts or deployment leases are included. It does not install anything in a deployed database.

`python test_static.py` checks that the candidate adds exactly one field and that the fixtures execute the exact extraction expression.

`P16_QA_ALLOW_DISPOSABLE=1 python test_postgres.py` requires a loopback PostgreSQL 16 server. It creates a randomly named temporary database, builds synthetic tables/auth stub, checks the old and new complete RPCs, tests two owner identities and authentication rejection, asserts all 32 timestamp/association fixtures, restores the original function, then drops only that new test database. Connection settings reject non-loopback hosts and service configuration. Run only against the explicit disposable CI service.

The candidate adds `provider_item_updated_at` to each connection. It requires exactly one successful sync with the same user, connection, and finish time as last_success_at. Missing, malformed, ambiguous or unmatched source data yields JSON null. The source is only `metadata.item.lastUpdatedAt`; no collector-date fallback, old-run fallback, raw metadata or extra identifiers are returned. pg_input_is_valid plus nested CASE guards timestamp casts, and timestamp types are schema-qualified.

All pre-existing output keys, auth, function signature, owner, ACL and config are preserved. The baseline includes pre-existing IDs in its existing contract; the new field adds no IDs. The user-facing date represents the provider connection's reported update, not certification of every balance or transaction.
