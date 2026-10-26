# Verify financial reads without an application identity

The two administrative probes exercise the existing database permissions and
financial read RPCs without creating an identity, setting JWT claims or invoking
financial writers. They run in read-only repeatable-read transactions, use
bounded statements, restore the execution role and roll back. They change no
schema, function, policy, grant, setting outside their transaction or source row.

`backend/qa/lts_missing_session_read_probe.sql` calls only an explicit family of
financial read RPCs executable by the authenticated role. Arguments are typed
NULLs; no owner ID or financial payload is supplied. Each protected reader must
reject the missing session with an authorization error. A successful/empty
response, business-validation error, read-only violation, timeout or unrelated
error fails the probe. Legacy readers that delegate their guard are exercised
too. Mutation, refresh, upload and provider-ingestion RPCs are excluded.

`backend/qa/lts_missing_session_rows_probe.sql` counts non-NULL owner rows in
scoped financial relations under the anonymous and authenticated roles. It covers
both `user_id` and legacy `usuario_id` UUID columns and owner-scoped financial
views. Permission denial or zero visible owner rows passes. Shared rows without
an owner are not mistaken for private rows. Health and authentication records
are excluded. The probe separately checks the two financial Storage buckets:
both must exist and remain private, and no object metadata may be visible without
an identity. It reads no stored-file bytes.

Use an authorized administrative connection with no application identity. The
probes refuse a connection already carrying an application user. Retain their
complete private receipts and inspect any unexpected outcome; do not change
permissions or financial records merely to make an audit pass.

The PostgreSQL 17 workflow runs both actual probe files against synthetic data.
It verifies denial and private-row isolation, then injects seven failures: an
unguarded reader, a business error, a read-only write attempt, an unprotected
table, a definer view bypassing owner RLS, a public financial bucket and an empty
read-coverage inventory. Each must
be detected. The fixture also checks Health exclusion, shared rows, legacy owner
columns, delegated guards and source preservation. No production data enters CI.

These checks establish a native database-role boundary for missing sessions.
They do not establish valid signed HTTP sessions for a second owner, every writer's
behavior, administrative Auth configuration, file-download authorization or a
full database/Storage restoration. Those acceptances remain separate. The app,
existing release assets, query deadlines and financial behavior are unchanged.
