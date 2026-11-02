DO $guard$ BEGIN
IF position('v403-write-policy' IN pg_get_functiondef('public.lts_open_finance_finish_bank_v1(uuid,uuid,text,jsonb,text)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_finish_bank_v1(uuid,uuid,text,jsonb,text)'::regprocedure))<>'3d85d8587666e42fc29b4758a9a3569e' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_finish_bank_v1';END IF;
IF position('v403-write-policy' IN pg_get_functiondef('public.lts_open_finance_finish_itau_v1(uuid,uuid,text,jsonb,text)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_finish_itau_v1(uuid,uuid,text,jsonb,text)'::regprocedure))<>'7af292cc25716fdb7fc10e73d81b6f40' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_finish_itau_v1';END IF;
IF position('v403-write-policy' IN pg_get_functiondef('public.lts_open_finance_report_itau_v1(uuid,uuid,integer)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_report_itau_v1(uuid,uuid,integer)'::regprocedure))<>'b169f9a3c0b6a01d90b5d4ebb62ab7e5' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_report_itau_v1';END IF;
IF position('v403-write-policy' IN pg_get_functiondef('public.lts_open_finance_stage_batch_bank_v1(uuid,uuid,uuid,jsonb)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_stage_batch_bank_v1(uuid,uuid,uuid,jsonb)'::regprocedure))<>'cf7d0fe62bfcd50de7b7b9613c3cc9d9' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_stage_batch_bank_v1';END IF;
IF position('v403-write-policy' IN pg_get_functiondef('public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb)'::regprocedure))<>'10899b4dcbd65f6ad32f6386d95b4f1e' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_stage_batch_v1';END IF;
END $guard$;
-- V403: only new/material source observations, plus every balance/investment cohort.
-- Original observations and financial rows are never updated or deleted.
CREATE OR REPLACE FUNCTION public.lts_observation_fingerprint_v403(p_hash text,p_raw jsonb,p_normalized jsonb,p_reconciliation jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $function$
 SELECT encode(sha256(convert_to(jsonb_build_array(p_hash,p_raw,p_normalized,p_reconciliation)::text,'UTF8')),'hex');
$function$;

CREATE OR REPLACE FUNCTION public.lts_observation_run_stats_v403(p_run uuid,p_user uuid,p_meta jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $function$
WITH receipts AS MATERIALIZED(
 SELECT value FROM jsonb_each(p_meta->'_v403_receipts')
), old_stats AS(
 SELECT jsonb_build_object('total',count(*),'exact',count(*) FILTER(WHERE reconciliation->>'classification'='exact'),
 'candidate',count(*) FILTER(WHERE reconciliation->>'classification'='candidate'),'new',count(*) FILTER(WHERE reconciliation->>'classification'='new'),
 'conflict',count(*) FILTER(WHERE reconciliation->>'classification'='conflict'),'inserted',count(*) FILTER(WHERE ingest_action='inserted'),
 'updated',count(*) FILTER(WHERE ingest_action='updated'),'unchanged',count(*) FILTER(WHERE ingest_action='unchanged'),
 'stale',count(*) FILTER(WHERE ingest_action='stale')) j
 FROM public.lts_open_finance_observation WHERE sync_run_id=p_run AND user_id=p_user
), new_stats AS(
 SELECT jsonb_build_object('total',count(*),'exact',count(*) FILTER(WHERE value->>1='exact'),
 'candidate',count(*) FILTER(WHERE value->>1='candidate'),'new',count(*) FILTER(WHERE value->>1='new'),
 'conflict',count(*) FILTER(WHERE value->>1='conflict'),'inserted',count(*) FILTER(WHERE value->>2='inserted'),
 'updated',count(*) FILTER(WHERE value->>2='updated'),'unchanged',count(*) FILTER(WHERE value->>2='unchanged'),
 'stale',count(*) FILTER(WHERE value->>2='stale'),'observations_stored',count(*) FILTER(WHERE (value->>3)::boolean),
 'unchanged_not_repeated',count(*) FILTER(WHERE NOT(value->>3)::boolean),
 'source_set_sha256',encode(sha256(convert_to((p_meta->'_v403_receipts')::text,'UTF8')),'hex'),
 'policy','v403-write-policy')j FROM receipts
)
SELECT CASE WHEN p_meta?'_v403_receipts' THEN (SELECT j FROM new_stats) ELSE(SELECT j FROM old_stats)END;
$function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_stage_batch_core_v403(p_user_id uuid,p_connection_id uuid,p_run_id uuid,p_records jsonb,p_codes text[])
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $function$
DECLARE r public.lts_open_finance_sync_run;c public.lts_open_finance_connection;
 x jsonb;old public.lts_open_finance_staging;classification text;action text;stage_status text;
 receipts jsonb;receipt_key text;fp text;prior jsonb;same_material boolean;retain boolean;
 touches jsonb:='[]';n integer:=0;accepted integer:=0;
BEGIN
 -- v403-write-policy: serialized, exact per-record retries while the run is open.
 SELECT * INTO r FROM public.lts_open_finance_sync_run WHERE id=p_run_id FOR UPDATE;
 IF r.id IS NULL OR r.user_id IS DISTINCT FROM p_user_id OR r.connection_id IS DISTINCT FROM p_connection_id OR r.status IS DISTINCT FROM 'running' THEN RAISE EXCEPTION 'INVALID_RUNNING_SYNC';END IF;
 IF NOT pg_try_advisory_xact_lock_shared(hashtextextended('lts-maintenance-v403:'||p_user_id::text,0)) THEN RAISE EXCEPTION 'BACKUP_IN_PROGRESS_RETRY_LATER';END IF;
 SELECT * INTO c FROM public.lts_open_finance_connection WHERE id=p_connection_id AND user_id=p_user_id AND provider='pluggy' AND institution_code=ANY(p_codes);
 IF c.id IS NULL THEN RAISE EXCEPTION 'INVALID_CONNECTION';END IF;
 IF p_records IS NULL OR jsonb_typeof(p_records)<>'array' OR jsonb_array_length(p_records)>100 THEN RAISE EXCEPTION 'INVALID_BATCH';END IF;
 receipts:=r.metadata->'_v403_receipts';
 IF receipts IS NULL THEN
  -- An existing V402 run can finish safely across this migration.
  SELECT coalesce(jsonb_object_agg(o.resource_type||chr(31)||o.provider_record_id,
   jsonb_build_array(public.lts_observation_fingerprint_v403(o.raw_hash,o.raw_payload,o.normalized_payload,o.reconciliation),
    o.reconciliation->>'classification',o.ingest_action,true)),'{}') INTO receipts
  FROM public.lts_open_finance_observation o WHERE o.sync_run_id=p_run_id AND o.user_id=p_user_id;
 END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_records) LOOP
  IF x->>'provider_record_id' IS NULL OR x->>'resource_type' IS NULL OR x->>'resource_type'=''
   OR position(chr(31) IN x->>'resource_type')>0 OR position(chr(31) IN x->>'provider_record_id')>0
   OR x->>'provider_record_id' NOT LIKE c.provider_connection_ref||':%'
   OR x->>'raw_hash' IS NULL OR x->>'raw_hash'!~'^[0-9a-f]{64}$'
   OR x->'normalized_payload'->>'item_id' IS DISTINCT FROM c.provider_connection_ref THEN RAISE EXCEPTION 'INVALID_RECORD_SCOPE';END IF;
  classification:=x->'reconciliation'->>'classification';
  IF classification IS NULL OR classification NOT IN('exact','candidate','new','conflict') THEN RAISE EXCEPTION 'INVALID_RECONCILIATION';END IF;
  receipt_key:=(x->>'resource_type')||chr(31)||(x->>'provider_record_id');
  fp:=public.lts_observation_fingerprint_v403(x->>'raw_hash',x->'raw_payload',x->'normalized_payload',x->'reconciliation');
  prior:=receipts->receipt_key;
  IF prior IS NOT NULL THEN
   IF prior->>0 IS DISTINCT FROM fp THEN RAISE EXCEPTION 'RETRY_PAYLOAD_CHANGED';END IF;
   CONTINUE;
  END IF;
  stage_status:=CASE classification WHEN 'exact' THEN 'matched_exact' WHEN 'candidate' THEN 'matched_candidate' WHEN 'conflict' THEN 'blocked' ELSE 'normalized' END;
  SELECT * INTO old FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND provider='pluggy' AND resource_type=x->>'resource_type' AND provider_record_id=x->>'provider_record_id' FOR UPDATE;
  IF old.id IS NOT NULL AND old.connection_id IS DISTINCT FROM p_connection_id THEN RAISE EXCEPTION 'RECORD_CONNECTION_MISMATCH';END IF;
  action:=CASE WHEN old.id IS NULL THEN 'inserted' WHEN old.raw_hash=x->>'raw_hash' THEN 'unchanged'
   WHEN old.provider_updated_at IS NOT NULL AND nullif(x->>'provider_updated_at','')::timestamptz<old.provider_updated_at THEN 'stale' ELSE 'updated' END;
  -- source_sync_at is collection freshness, not a changed transaction.
  same_material:=old.id IS NOT NULL AND old.raw_hash=x->>'raw_hash' AND old.raw_payload=x->'raw_payload'
   AND (old.normalized_payload-ARRAY['reconciliation','source_sync_at'])=((x->'normalized_payload')-'source_sync_at')
   AND old.normalized_payload->'reconciliation'=x->'reconciliation';
  -- Keep the entire investment/balance cohort on EVERY collection for V402.
  -- Unknown future resource types remain fully observed until reviewed.
  retain:=NOT coalesce(same_material,false) OR action='stale'
   OR x->>'resource_type' NOT IN('transaction','card_transaction','investment_transaction','invoice','account','credit_card');
  IF retain THEN
   INSERT INTO public.lts_open_finance_observation(user_id,connection_id,sync_run_id,resource_type,provider_record_id,raw_hash,raw_payload,normalized_payload,reconciliation,ingest_action)
   VALUES(p_user_id,p_connection_id,p_run_id,x->>'resource_type',x->>'provider_record_id',x->>'raw_hash',x->'raw_payload',x->'normalized_payload',x->'reconciliation',action);
   n:=n+1;
  END IF;
  IF action<>'stale' THEN
   IF same_material THEN
    touches:=touches||jsonb_build_array(jsonb_build_object('id',old.id,'has_source_sync_at',x->'normalized_payload'?'source_sync_at','source_sync_at',x#>'{normalized_payload,source_sync_at}'));
   ELSE
      insert into public.lts_open_finance_staging(user_id,connection_id,sync_run_id,provider,resource_type,provider_record_id,provider_account_ref,
        institution_code,institution_name,occurred_at,posting_date,reference_month,signed_amount,currency,description_raw,description_normalized,
        normalized_payload,raw_payload,raw_hash,match_status,promotion_status,block_reason,source_event_type,provider_updated_at,matched_source_table,matched_source_ref)
      values(p_user_id,p_connection_id,p_run_id,'pluggy',x->>'resource_type',x->>'provider_record_id',x->>'provider_account_ref',
        c.institution_code,c.institution_name,nullif(x->>'occurred_at','')::timestamptz,nullif(x->>'posting_date','')::date,nullif(x->>'reference_month','')::date,
        nullif(x->>'signed_amount','')::numeric,x->>'currency',x->>'description_raw',lower(x->>'description_raw'),
        (x->'normalized_payload')||jsonb_build_object('reconciliation',x->'reconciliation'),x->'raw_payload',x->>'raw_hash',stage_status,'blocked',
        'shadow_only_no_promotion','snapshot',nullif(x->>'provider_updated_at','')::timestamptz,
        case when classification='exact' then x->'reconciliation'->'candidates'->0->>'table' end,
        case when classification='exact' then x->'reconciliation'->'candidates'->0->>'ref' end)
      on conflict(user_id,provider,resource_type,provider_record_id) do update set
        sync_run_id=excluded.sync_run_id,provider_account_ref=excluded.provider_account_ref,occurred_at=excluded.occurred_at,
        posting_date=excluded.posting_date,reference_month=excluded.reference_month,signed_amount=excluded.signed_amount,currency=excluded.currency,
        description_raw=excluded.description_raw,description_normalized=excluded.description_normalized,normalized_payload=excluded.normalized_payload,
        raw_payload=excluded.raw_payload,raw_hash=excluded.raw_hash,match_status=excluded.match_status,promotion_status='blocked',block_reason=excluded.block_reason,
        matched_source_table=excluded.matched_source_table,matched_source_ref=excluded.matched_source_ref,match_confidence=null,
        provider_updated_at=excluded.provider_updated_at,last_seen_at=now(),updated_at=now();

   END IF;
  END IF;
  receipts:=jsonb_set(receipts,ARRAY[receipt_key],jsonb_build_array(fp,classification,action,retain));
  accepted:=accepted+1;
 END LOOP;
 -- One clock-only statement per batch; original financial payloads are reused.
 UPDATE public.lts_open_finance_staging s SET sync_run_id=p_run_id,last_seen_at=now(),updated_at=now(),
  normalized_payload=CASE WHEN (t->>'has_source_sync_at')::boolean THEN jsonb_set(s.normalized_payload,'{source_sync_at}',t->'source_sync_at') ELSE s.normalized_payload-'source_sync_at' END
 FROM jsonb_array_elements(touches)t WHERE s.id=(t->>'id')::uuid AND s.user_id=p_user_id AND s.connection_id=p_connection_id;
 UPDATE public.lts_open_finance_sync_run SET metadata=jsonb_set(coalesce(metadata,'{}'),'{_v403_receipts}',receipts) WHERE id=p_run_id;
 RETURN jsonb_build_object('observations_inserted',n,'received_unique_in_batch',accepted,'promotion_enabled',false,'history_policy','v403-write-policy');
END $function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_stage_batch_v1(p_user_id uuid,p_connection_id uuid,p_run_id uuid,p_records jsonb)
RETURNS jsonb LANGUAGE sql SET search_path='' AS $function$
 -- v403-write-policy
 SELECT public.lts_open_finance_stage_batch_core_v403(p_user_id,p_connection_id,p_run_id,p_records,ARRAY['341']);
$function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_stage_batch_bank_v1(p_user_id uuid,p_connection_id uuid,p_run_id uuid,p_records jsonb)
RETURNS jsonb LANGUAGE sql SET search_path='' AS $function$
 -- v403-write-policy
 SELECT public.lts_open_finance_stage_batch_core_v403(p_user_id,p_connection_id,p_run_id,p_records,ARRAY['237','336']);
$function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_finish_itau_v1(p_user_id uuid, p_run_id uuid, p_status text, p_metadata jsonb, p_error_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run; stats jsonb;
begin
 -- v403-write-policy: received coverage remains independent of payload storage.
  select * into r from public.lts_open_finance_sync_run where id=p_run_id and user_id=p_user_id for update;
  if r.id is null or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  if p_status is null or p_status not in ('success','partial','failed') then raise exception 'INVALID_SYNC_STATUS'; end if;
  if p_error_code is not null and p_error_code !~ '^[A-Z0-9_]{1,80}$' then raise exception 'INVALID_ERROR_CODE'; end if;
  stats:=public.lts_observation_run_stats_v403(p_run_id,p_user_id,r.metadata);
  if p_status='success' and ((stats->>'total')::int=0 or coalesce((p_metadata->>'expected_count')::int,-1)<>(stats->>'total')::int
    or exists(select 1 from jsonb_array_elements(coalesce(p_metadata->'coverage','[]')) x where x->>'status'='unavailable')) then raise exception 'INCOMPLETE_SUCCESS_NOT_ALLOWED'; end if;
  update public.lts_open_finance_sync_run set status=p_status,finished_at=now(),raw_count=(stats->>'total')::int,normalized_count=(stats->>'total')::int,
    exact_match_count=(stats->>'exact')::int,candidate_match_count=(stats->>'candidate')::int,blocked_count=(stats->>'conflict')::int,promoted_count=0,
    error_code=p_error_code,error_summary=case when p_error_code is not null then 'Shadow sync incomplete; see safe error code.' end,
    metadata=(metadata-'_v403_receipts')||(p_metadata-'_v403_receipts')||jsonb_build_object('counts',stats,'promotion_enabled',false)||CASE WHEN r.metadata?'_v403_receipts' THEN jsonb_build_object('ingestion_v403',stats) ELSE '{}'::jsonb END where id=p_run_id;
  update public.lts_open_finance_connection set last_success_at=case when p_status='success' then now() else last_success_at end,
    last_error_code=p_error_code,last_error_summary=case when p_error_code is not null then 'Shadow sync incomplete.' end,updated_at=now() where id=r.connection_id;
  return jsonb_build_object('run_id',p_run_id,'status',p_status,'counts',stats,'promotion_enabled',false);
end $function$;

CREATE OR REPLACE FUNCTION public.lts_open_finance_finish_bank_v1(p_user_id uuid, p_run_id uuid, p_status text, p_metadata jsonb, p_error_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run;c public.lts_open_finance_connection;cnt int;stats jsonb;
begin
 -- v403-write-policy: received coverage remains independent of payload storage.
 if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
 select * into r from public.lts_open_finance_sync_run where id=p_run_id for update;if not found or r.user_id<>p_user_id then raise exception 'RUN_OWNER_MISMATCH';end if;
 stats:=public.lts_observation_run_stats_v403(p_run_id,p_user_id,r.metadata);cnt:=(stats->>'total')::integer;
 if r.metadata?'_v403_receipts' and p_status='success' and (coalesce((p_metadata->>'expected_count')::integer,-1)<>cnt or exists(select 1 from jsonb_array_elements(coalesce(p_metadata->'coverage','[]'))x where x->>'status'='unavailable')) then raise exception 'INCOMPLETE_SUCCESS_NOT_ALLOWED';end if;
 update public.lts_open_finance_sync_run set status=p_status,finished_at=now(),raw_count=cnt,normalized_count=cnt,promoted_count=0,error_code=p_error_code,metadata=(coalesce(metadata,'{}')-'_v403_receipts')||(coalesce(p_metadata,'{}')-'_v403_receipts')||CASE WHEN r.metadata?'_v403_receipts' THEN jsonb_build_object('counts',stats,'ingestion_v403',stats) ELSE '{}'::jsonb END where id=p_run_id returning * into r;
 select * into c from public.lts_open_finance_connection where id=r.connection_id;
 update public.lts_open_finance_connection set last_error_code=p_error_code,last_error_summary=case when p_error_code is null then null else 'Sincronização não concluída; tente novamente.' end,last_attempt_at=now(),last_success_at=case when p_status in ('success','partial') then now() else last_success_at end,status=case when p_status in ('success','partial') then 'connected' else status end where id=c.id;
 return jsonb_build_object('run_id',r.id,'connection_id',r.connection_id,'status',r.status,'raw_count',r.raw_count,'normalized_count',r.normalized_count,'promoted_count',0,'error_code',r.error_code,'metadata',r.metadata);
end $function$;

CREATE OR REPLACE FUNCTION public.lts_open_finance_report_itau_v1(p_user_id uuid, p_run_id uuid DEFAULT NULL::uuid, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run;
begin
 -- v403-write-policy: stored source changes and positions are separate from coverage counts.
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
  if p_offset<0 then raise exception 'INVALID_OFFSET'; end if;
  select s.* into r from public.lts_open_finance_sync_run s join public.lts_open_finance_connection c on c.id=s.connection_id
    where s.user_id=p_user_id and c.provider='pluggy' and c.institution_code='341' and (p_run_id is null or s.id=p_run_id)
    order by s.started_at desc limit 1;
  if r.id is null then return jsonb_build_object('status','not_synced','promotion_enabled',false); end if;
  return jsonb_build_object('run',to_jsonb(r),'total',(select count(*) from public.lts_open_finance_observation where sync_run_id=r.id),
    'received_total',r.raw_count,'observation_storage_policy',coalesce(r.metadata#>>'{ingestion_v403,policy}','legacy-all-records'),'offset',p_offset,'page_size',200,'promotion_enabled',false,'records',coalesce((select jsonb_agg(j) from (
      select jsonb_build_object('resource_type',o.resource_type,'provider_record_id',o.provider_record_id,'raw_hash',o.raw_hash,
        'normalized',o.normalized_payload,'reconciliation',o.reconciliation,'ingest_action',o.ingest_action) j
      from public.lts_open_finance_observation o where o.sync_run_id=r.id and o.user_id=p_user_id order by o.resource_type,o.provider_record_id limit 200 offset p_offset) q),'[]'::jsonb));
end $function$;

REVOKE ALL ON FUNCTION public.lts_observation_fingerprint_v403(text,jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_observation_run_stats_v403(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_open_finance_stage_batch_core_v403(uuid,uuid,uuid,jsonb,text[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_observation_fingerprint_v403(text,jsonb,jsonb,jsonb),public.lts_observation_run_stats_v403(uuid,uuid,jsonb),public.lts_open_finance_stage_batch_core_v403(uuid,uuid,uuid,jsonb,text[]) TO service_role;
