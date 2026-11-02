# Daily backup coverage after the family loan extension

V398 extended the modern export from 31 to 33 tables but left the scheduled
writer fixed at 31 and the reader limited to 29/31. A new capture would reject
the family inputs, and a valid 33-table bundle could not be read.

Apply `backup_manifest.sql`, then `bounded_backup_job.sql`. The former validates
the exact table sets, array types, row counts and declared coverage for all
three historical profiles. New captures require both family tables and both
notification journals. Invalid exports fail before legacy diagnostics execute.
Existing archives and their hashes are never changed.

The latter prepends a 90-second session timeout to the existing job command.
It preserves the schedule, owner, enabled state and original invocation.
It does not start a capture, retry a failed capture, change retention or alter
global/database/role timeout settings. PostgreSQL tests execute the resulting
command through a client connection and verify cancellation on a scaled timeout.

This fixes a proved pipeline incompatibility and bounds future runtime. It does
not establish why the database restarted on 2 November, certify a successful
next scheduled run, or certify full DB/Storage/Auth disaster recovery.

Run the isolated PostgreSQL 17 workflow `v401-backup-pipeline.yml`. Its baseline
loads the real V380, V387 and V398 migrations, reproduces the original failure,
then covers write/read/replay, historical bundles, malformed manifests, owner
scope, unchanged schedules, command cancellation and client access restrictions.
