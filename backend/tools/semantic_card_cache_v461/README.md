# Semantic card cache V461

An unchanged Open Finance collection used to invalidate the prepared product because both card fingerprints hashed only `id`, `sync_run_id`, `last_seen_at` and `updated_at`. These three collection bookkeeping fields do not represent a changed bank entry and are already excluded by the financial epoch trigger.

The two identical fingerprint producers now hash the entire staging row except those three fields. Amounts, dates, status, raw and normalized evidence, deleted entries, account ownership and future semantic columns remain covered independently of the existing epoch. Invoice, document and settlement hashing is unchanged. The cache producer and consumer must be installed together. Existing prepared records are naturally invalidated once because the formula changes.

`build.py` accepts only the exact V460 predecessor or its own installed definition. Installation and rollback refuse active workers or a busy worker advisory lock. They preserve function metadata, permissions, schema and timeouts, and update exactly two existing closed-profile pins. Neither script writes financial data or starts a worker.

The native PostgreSQL 17 workflow checks unchanged collection reuse, financial and receipt invalidation, owner isolation, incomplete cards, read-only operation, epoch races, metadata, profile consistency, idempotence and atomic drift refusal. Synthetic fixtures exercise the real function definitions; live performance acceptance is recorded privately and is separate from these tests.
