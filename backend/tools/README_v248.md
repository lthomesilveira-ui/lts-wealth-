# V248 — offline observation archive pilot, NOT a production migration

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

- Independently recover the COMPLETE archive including failed/partial runs (this
  pilot currently accepts successful complete runs only), manifest and checksums.
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
