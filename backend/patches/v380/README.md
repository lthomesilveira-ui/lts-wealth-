# V380: daily supplement for modern financial records

The legacy daily exporter omits classifications, historical card compositions, documentary schedules, amount overrides and related modern data. V380 adds a separate private daily supplement covering 29 explicitly listed tables, linked to the unchanged legacy snapshot by date and integrity hashes. The existing backup job calls the new idempotent wrapper at its existing time; no second job is created.

The reader verifies both payloads and returns a new `lts-recovery-bundle-v380` envelope. It cannot be passed to the old v1 restorer as if modern data were supported. Both capture timestamps remain explicit; a single transactionally consistent full-project snapshot is not claimed. Service-only invoker functions and an RLS-protected table keep the bundle outside anonymous and ordinary authenticated access.

The native PostgreSQL 17 CI uses schema-only fixtures and synthetic owner records. It verifies role boundaries, owner selection, null/unknown owner and date rejection, first capture, idempotency, payload/manifest corruption rejection, temporary-table recovery of a classification and preservation of the existing job. Production validation must separately verify actual captures and source invariants.

This is additional data protection. Full database/schema/roles/auth recovery, document and Storage binaries, private HTTP sessions, physical devices and acceptance of all consumers remain separate outstanding work. No financial source records, classifications, dates or balances are changed by the patch.
