# Claim newly prepared work in the same scheduler pass

The existing preparation function captured its eligibility time before enqueue.
The enqueue function sets next_attempt_at using a later clock_timestamp(), so
work created by preparation missed that same pass and waited for the next cron
invocation. Refresh the local timestamp after enqueue and before claiming.

No schedule, worker, frontend, timeout, financial policy or source row changes.
Owner/version/epoch checks, retry backoff, lease protection and SKIP LOCKED stay
unchanged. Guarded installation refuses a divergent predecessor or active worker
and verifies that owner, ACL, security mode and function settings are preserved.
A guarded rollback is included. Run build_install.py to reproduce both scripts.

Run test_native.py against a disposable native PostgreSQL 17 service via standard
PG environment variables. It creates a synthetic test database. Tests cover the
original missed claim, same-pass recovery, retries, leases, two-session advisory
and row contention, metadata preservation, installation, rollback and drift.
Fixtures stub application dependencies; they are not full application acceptance.

The exact patch was installed with protected version checks and observed taking
new work in the same normal scheduler pass. End-to-end opening remains a separate
unresolved acceptance; private evidence and real financial values are excluded.
