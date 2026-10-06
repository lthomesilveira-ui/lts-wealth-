-- Historical inventory + bounded export, READ ONLY. No schema or source writes.
-- Bind owner_id, project_ref and sync_run_id in a trusted client.
-- Keep results private. Preserve legacy status/counters, even if inconsistent.
-- First inventory: counts/metadata only; never globally aggregate every payload.
BEGIN READ ONLY; SET LOCAL statement_timeout='90000'; SET LOCAL work_mem='32MB'; SET LOCAL timezone='UTC'; SET LOCAL max_parallel_workers_per_gather=0;
WITH inventory AS(
 SELECT r.id::text run_id,r.status,to_jsonb(r)::text metadata,
 (SELECT count(*) FROM public.lts_open_finance_observation o WHERE o.sync_run_id=r.id AND o.user_id=r.user_id) observation_count
 FROM public.lts_open_finance_sync_run r WHERE r.user_id=:'owner_id' AND r.status IN('success','partial','failed','cancelled') AND r.finished_at IS NOT NULL
)
SELECT jsonb_build_object('format','lts-observation-inventory-v248','source_project',:'project_ref','owner_id',:'owner_id','checked_at',now()::text,
'field_schema',ARRAY['id','user_id','connection_id','sync_run_id','resource_type','provider_record_id','raw_hash','raw_payload','normalized_payload','reconciliation','ingest_action','observed_at'],
'rows',(SELECT sum(observation_count) FROM inventory),'runs',(SELECT count(*) FROM inventory),
'nonterminal_runs',(SELECT count(*) FROM public.lts_open_finance_sync_run WHERE user_id=:'owner_id' AND (status='running' OR finished_at IS NULL)),
'actual_rows',(SELECT count(*) FROM public.lts_open_finance_observation WHERE user_id=:'owner_id'),
'catalog',(SELECT jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable) ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name='lts_open_finance_observation'),
'inventory',(SELECT jsonb_agg(inventory ORDER BY run_id) FROM inventory)) AS snapshot; ROLLBACK;

-- Separate bounded run export. Keep the twelve PostgreSQL text values exact.
-- SQL source_vectors_sha256 uses LF-separated ordered text vectors; an empty
-- closed run hashes the empty UTF-8 string and remains part of the inventory.
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET LOCAL statement_timeout='20000'; SET LOCAL work_mem='32MB'; SET LOCAL timezone='UTC'; SET LOCAL max_parallel_workers_per_gather=0;
WITH data AS MATERIALIZED(
 SELECT o.id::text id,o.user_id::text user_id,o.connection_id::text connection_id,o.sync_run_id::text sync_run_id,o.resource_type,o.provider_record_id,o.raw_hash,o.raw_payload::text raw_payload,o.normalized_payload::text normalized_payload,o.reconciliation::text reconciliation,o.ingest_action,o.observed_at::text observed_at
 FROM public.lts_open_finance_observation o WHERE o.sync_run_id=:'sync_run_id'::uuid AND o.user_id=:'owner_id'
)
SELECT jsonb_build_object('format','lts-observation-export-v2','source_project',:'project_ref','owner_id',:'owner_id','exported_at',now()::text,
'run_metadata',(SELECT to_jsonb(r)::text FROM public.lts_open_finance_sync_run r WHERE r.id=:'sync_run_id'::uuid AND r.user_id=:'owner_id'),
'row_count',count(*),'rows',coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.id),'[]'::jsonb),
'source_vectors_sha256',encode(pg_catalog.sha256(convert_to(coalesce(string_agg(array_to_json(ARRAY[d.id,d.user_id,d.connection_id,d.sync_run_id,d.resource_type,d.provider_record_id,d.raw_hash,d.raw_payload,d.normalized_payload,d.reconciliation,d.ingest_action,d.observed_at])::text,E'\n' ORDER BY d.id),''),'UTF8')),'hex')) AS sample FROM data d; ROLLBACK;
