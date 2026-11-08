# V427: reuse an unchanged consultation payload

The V403 grouped staging update rebuilt `normalized_payload` even when the
provider consultation clock was identical. For externally stored JSON this can
write a new TOAST value on every consultation, although its contents are equal.

V427 assigns the existing column when the clock is equal or already absent.
Changed, removed and JSON-null clocks retain their original behavior. Run IDs,
last-seen timestamps, receipts, classifications and financial values are
unchanged. The observation policy still retains every complete balance and
investment cohort required by the daily Cofrinho reader.

Apply `reuse_unchanged_payload.sql` atomically when no collection is running.
The migration locks the existing bank entry points, checks the exact predecessor
and permissions, preserves all function attributes, and supports exact replay.
It changes no historical rows, schedules, retention, credentials or interface.

Native verification exercises the real V403 ingestion and V402 Cofrinho chain,
including retries and changes to values. Additional cases cover identical,
changed, absent, removed and JSON-null clocks through the actual ingestion API.
The optional WAL probe uses invented large payloads only. Its WAL/time result is
a controlled example, not a measurement of production IOPS or a full recovery
certificate. Production acceptance must separately verify source/value parity,
natural collections and platform metrics.
