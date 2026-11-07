# V420 fixed helper execution context

This metadata-only change sets an empty function search path on the two pure production normalization helpers that lacked an explicit setting. Their SQL bodies already qualify ordinary function references. The change resolves those two mutable-search-path advisories as defense in depth; it is not evidence of a discovered exploit or of a completed cross-user security acceptance.

Exact predecessor definitions are guarded. Function bodies, owners, grants, volatility, strictness and all other catalog attributes are preserved. Applying the same package again is idempotent. No financial table, recurring policy, cache, scheduler, login configuration or immutable release is changed.

PostgreSQL17 tests compare 415 invented inputs for both functions under three caller search paths, before and after installation and replay. Before production activation, also verify actual current descriptors without exporting them; record only counts, hashes and equality. Historical restore/synthetic schemas are intentionally left unchanged.

References: Supabase Security Advisor check 0011 (function search path mutable), PostgreSQL17 ALTER FUNCTION SET configuration_parameter. Use the normal reviewed migration action for production installation. Do not present these limited checks as the outstanding test between two real authorized identities.
