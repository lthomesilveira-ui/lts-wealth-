# D30 synthetic contracts

These tests run only in a disposable PostgreSQL16 service with synthetic fixtures and temporary fixtures and rollback-scoped candidate definitions. They do not connect to a deployed application database. The SQL ends with ROLLBACK and has bounded statement and lock timeouts.

The reviewed candidate function bodies are embedded with explicit pg_temp replacements for dependencies. Tests cover short/long date boundaries, anchoring of eligible D0 liquidity, complete30-day coverage, NULL and duplicate dates, and slice cold/warm behavior. They do not prove actual source correctness, full production dependency behavior, frontend presentation, or full production dependency performance. The full12001-day synthetic gate measures only the candidate reader with stubbed dependencies. A separate DDL roundtrip verifies canonical definition hashes without executing source readers.

CI is an independent code validation, not a record of any pending database-tool execution. There is no installation, deployment, credential, account data, or private financial receipt in this directory.
