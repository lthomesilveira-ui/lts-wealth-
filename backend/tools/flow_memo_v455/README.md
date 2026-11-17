# Optional flow-key memo persistence

An expired flow-source-key memo previously executed a blocking upsert after the
correct source key was already computed. A concurrent transaction holding that
derived row could exhaust the reader's statement deadline. Reuse the existing
V430 private optional-write helper: try the advisory lock, bound only the memo
write to at most 100 ms, then return the identical computed key if persistence
cannot proceed.

The patch changes only that upsert. It preserves the complete source key,
five-minute TTL, source-epoch fence, bank freshness and scheduled-transfer
revision. Source errors remain errors. No financial rows, balances, categories,
jobs, timeout limits for source reads or frontend assets are changed. Installer
and rollback require the exact predecessor and existing helper definitions and
preserve all function metadata and permissions.

Run `python3 backend/tools/flow_memo_v455/build.py` to reproduce the guarded SQL.
The native PostgreSQL 17 workflow proves the old failure and new response using
two real database sessions, then checks exact keys, invalidation, read-only
transactions, owner isolation, metadata, private access, repeat installation,
rollback and rejection of concurrent code changes. All fixtures are synthetic.
Passing these tests does not certify end-to-end application performance.
