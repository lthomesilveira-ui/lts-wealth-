# Isolated presentation envelope tests

This package tests only the new presentation helpers' installation and recovery. It does not install in production or publish UI. The already-reviewed presentation SQL/JS files remain frozen in `../public`.

`build_envelope.py` is byte-identical to the private renderer. `build_read.py` uses the same catalogue/fingerprint SQL but a fictional UUID target. No private lease, source document, canonical invoice, original evidence, or manifest is included.

The runner requires an explicit disposable PG17 opt-in and hardcodes loopback, database/user `lts_p05_synthetic`, and a synthetic password. It first requires the public schema to contain no relations. Only after that guard may it reset that synthetic schema between cases. Business-reader and financial-guard stubs raise if invoked.

It proves successful apply/recovery, exact annotation allowlist, original caller OID/ACL preservation, unchanged source/link/contract rows and financial functions, removal of inherited default grants, refusal of stale/future leases, function/source/contract/epoch drift, and atomic rollback after DDL failures. Recovery tests both tracked dependencies and later textual callers, using DROP RESTRICT only in the migration.

Private execution prerequisites remain separate: reviewed exact artifact, fresh read-only lease (10 minutes), authorized apply, and an installation receipt. Recovery additionally binds fresh metadata to that receipt; a fresh read does not authorize accepting divergent installed objects. The private read-only lease query must be renewed immediately before an eventual apply. This test package does not supply production leases.
