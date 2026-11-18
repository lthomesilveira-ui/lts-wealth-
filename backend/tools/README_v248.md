# V248 — offline observation archives, NOT a production migration

This isolated candidate stores exact scoped content once, retains every
observation UUID, run, action and microsecond/timezone timestamp, and reconstructs
all 12 source fields. It has no network client, credentials, SQL write, deletion,
retention schedule, Storage mutation or cache invalidation. Nothing is deployed.

Financial JSONB MUST be exported as PostgreSQL `::text`, not decoded/re-encoded
as JavaScript numbers or binary floats. Exact strings are compared before sharing
content. SHA256 is for corruption checks; different content with a hash collision
fails closed. Raw hashes alone never determine normalization or reconciliation
identity. Identical observed content is not a duplicated financial transaction.

## Safe pilot workflow

1. Read current capacity/read-only status and the exact observation schema.
   Compare the catalog result with all 12 codec FIELDS; abort on schema drift.
2. Use `observation_export_v248.sql` with bound owner/run/project parameters.
   Export only bounded completed runs; incomplete or cross-owner runs are rejected.
   Keep source exports private, outside the checkout and CI artifacts.
3. Run the synthetic test suite:

   `python3 -m unittest discover -s backend/qa -p 'test_lts_observation_archive_v248.py' -v`

4. Build a new archive (existing paths are never overwritten):

   `python3 backend/tools/lts_observation_archive_v248.py pack --exports PRIVATE_EXPORTS --owner OWNER_UUID --project PROJECT_REF --archive NEW_PRIVATE_PATH.json.gz`

5. Retain the printed checksum in a separately protected manifest. Run independent
   verification against the unchanged source exports:

   `python3 backend/tools/lts_observation_archive_v248.py verify --exports PRIVATE_EXPORTS --owner OWNER_UUID --project PROJECT_REF --archive PRIVATE_PATH.json.gz --sha256 TRUSTED_SHA256`

The verifier checks exact row equality against independent sources, every UUID,
every payload string, run count and original run metadata. It requires an external
checksum, rejects schema drift, duplicates, missing versions, truncated/trailing
gzip content, JSON duplicate keys and decompression above 64 MiB. Batch ceiling
100,000 rows; process much smaller batches in practice. Checksums are not signatures
and do not establish trust if the source and external manifest can both be changed.

## Deployment blockers and acceptance criteria

The prototype does NOT prove full-history recovery, database-size reduction,
sustainable Free capacity, production latency improvement, Storage durability,
RLS acceptance, or consumer parity. A gzipped export is not a rebuilt database.
Compare gzip without dictionary too: compression and deduplication are different.
Do not generalize a recent-run compression ratio to all 517k historical observations.

Before ANY original is removed:

- Independently recover the COMPLETE archive including failed/partial runs,
  manifest and checksums. The original pilot intentionally remains success-only;
  the separate historical codec below preserves other closed-run statuses.
- Preserve all source contracts: stage_batch_bank_v1, stage_batch_v1,
  finish_bank_v1, finish_itau_v1, report_itau_v1, flow_cache_pre_v240,
  browser_flow_pre_v238 and v246_invalidate_finance_cache. Preserve retry identity,
  run counts/status/coverage and changed-retry rejection. Keep dated checking
  observations needed for the first discrepancy date online or exactly queryable.
- Establish private owner/service-only Storage access using Storage API. Never
  manipulate object metadata via SQL or publish bank exports in git. Test upload,
  authenticated download, exact restore and denied cross-owner/anonymous reads.
- Design light online run receipts + recoverable archived rows, not perpetual
  full hourly reference rows; measure new indexes, manifests, growth and capacity
  headroom after a real rebuild. 350–400 MB is a proposed engineering target only.
- Resolve read-only/disk-full through the supported authorized platform route.
  No read-only override, pause/restore workaround, VACUUM FULL without extra space,
  paid upgrade, or new credentials extraction is implemented by this candidate.
- Collect fresh financial baseline and pass all consumer/flow/parity/privacy
  gates atomically. V247 remains an independent pending performance candidate.

No delete command exists in this tool. This PR must remain draft until the next
phase has a validated rollback, complete recovery and the above acceptance checks.

## Historical coverage extension

`lts_observation_snapshot_v248.py` is a separate offline codec. It accepts closed
success/partial/failed/cancelled runs against an independent owner-scoped SQL
inventory, including zero-row runs. Legacy `raw_count` is preserved exactly,
never substituted for the observed row count: failed runs can contain rows and
successful runs can have counters inconsistent with their historical rows.

Use `observation_historical_export_v248.sql` for the inventory and bounded run
exports. Each export carries a PostgreSQL SHA256 of the ordered twelve text
fields, independently recomputed by the codec. Keep the inventory, original
exports, compressed parts and separate checksum ledger private. Do not discard
source exports after a successful local reconstruction.

Pack small batches with `pack --inventory PRIVATE_INVENTORY --exports PRIVATE_EXPORTS
--owner OWNER_UUID --project PROJECT_REF --archive NEW_PRIVATE_PART.json.gz`.
After capturing every inventory run, run `verify-collection --inventory
PRIVATE_INVENTORY --ledger PRIVATE_LEDGER --directory PRIVATE_ARCHIVE_DIRECTORY
--source-directory PRIVATE_SOURCE_DIRECTORY --owner OWNER_UUID --project PROJECT_REF
--report NEW_PRIVATE_REPORT.json`. The collection verifier requires exact coverage
of the independent inventory, rejects duplicate run/observation UUIDs across parts,
checks each external archive checksum and compares all restored fields with the
retained independent exports.

Repeat the count-and-metadata inventory at the end and compare everything except
the check timestamp. Each run export has a repeatable-read snapshot; matching
start/end inventories does not make different export transactions one atomic
database backup. `database_restore_test` remains `NOT_RUN` until an isolated real
database restore, consumer parity, privacy, rollback and rebuilt-size tests pass.
Archiving alone neither frees production disk nor restores bank synchronization.

CI uses synthetic data only and runs both codecs' suites. Full bank archives,
original exports, real owner/run identifiers and private checksums must never be
added to this repository or public workflow artifacts.

### Optional smaller read-only transport

For at most six inventory runs, `observation_dictionary_transport_v248.sql` sends
each exact scoped eight-text-field tuple once, selected by PostgreSQL JSONB-array
equality, plus every observation's four reference fields. It does not use raw
hash equality to merge content. Original run metadata, actual counts and separate
SQL hashes of all twelve source text fields accompany the transport.

`expand-transport --inventory PRIVATE_INVENTORY --transport PRIVATE_TRANSPORT
--source-directory PRIVATE_SOURCES --owner OWNER_UUID --project PROJECT_REF`
validates and expands this into the same export-v2 sources. Retained overlapping
exports must have exactly identical rows, metadata and SQL source hashes; their
original capture timestamps/files are preserved. New files use exclusive creation
and mode 0600. Keep the original transport too. This only reduces export traffic,
not production database size, polling history, or financial transactions.
