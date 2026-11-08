-- Offline-pilot export only. Read-only, owner scoped, one COMPLETED run.
-- Client must bind :owner_id, :sync_run_id and :project_ref. No generated IDs here.
-- Verify the schema query equals the codec's 12 FIELDS before exporting any batch.
-- NEVER publish returned data, run IDs or checksums to the public repository.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '20000';
SET LOCAL work_mem = '16MB';
SET LOCAL timezone = 'UTC';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'lts_open_finance_observation'
ORDER BY ordinal_position;

-- Count and preflight size before asking the connector/client to return content.
SELECT count(*) AS rows,
       sum(octet_length(to_jsonb(o)::text)) AS approximate_transport_bytes
FROM public.lts_open_finance_observation o
WHERE o.user_id = :'owner_id'::uuid AND o.sync_run_id = :'sync_run_id'::uuid;

SELECT jsonb_build_object(
    'format', 'lts-observation-export-v1',
    'source_project', :'project_ref', 'owner_id', :'owner_id',
    'exported_at', now()::text,
    'run_metadata', (SELECT to_jsonb(r)::text
      FROM public.lts_open_finance_sync_run r
      WHERE r.id = :'sync_run_id'::uuid AND r.user_id = :'owner_id'::uuid
        AND r.status = 'success' AND r.finished_at IS NOT NULL),
    'row_count', count(*),
    'rows', coalesce(jsonb_agg(jsonb_build_object(
      'id', o.id::text, 'user_id', o.user_id::text,
      'connection_id', o.connection_id::text, 'sync_run_id', o.sync_run_id::text,
      'resource_type', o.resource_type, 'provider_record_id', o.provider_record_id,
      'raw_hash', o.raw_hash, 'raw_payload', o.raw_payload::text,
      'normalized_payload', o.normalized_payload::text,
      'reconciliation', o.reconciliation::text,
      'ingest_action', o.ingest_action, 'observed_at', o.observed_at::text)
      ORDER BY o.id), '[]'::jsonb)) AS sample
FROM public.lts_open_finance_observation o
WHERE o.sync_run_id = :'sync_run_id'::uuid AND o.user_id = :'owner_id'::uuid;
ROLLBACK;
