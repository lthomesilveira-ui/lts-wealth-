-- V249: update complete staged snapshots; preserve immutable observations and no promotion.
DO $guard$ BEGIN
 if md5(btrim(pg_get_functiondef('public.lts_open_finance_stage_batch_bank_v1(uuid,uuid,uuid,jsonb)'::regprocedure),E' \t\r\n'))<>'114db28136f0f49f2ae6827fd703441f' then raise exception 'V249_SOURCE_LEASE_CHANGED'; end if;
 if md5(btrim(pg_get_functiondef('public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb)'::regprocedure),E' \t\r\n'))<>'96ce5983938dacfcdbc5c06aeabb09ee' then raise exception 'V249_SOURCE_LEASE_CHANGED'; end if;
END $guard$;

CREATE OR REPLACE FUNCTION public.lts_open_finance_stage_batch_v1(p_user_id uuid, p_connection_id uuid, p_run_id uuid, p_records jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run; c public.lts_open_finance_connection;
  x jsonb; old public.lts_open_finance_staging; classification text; action text; stage_status text; n integer:=0;
begin
  select * into r from public.lts_open_finance_sync_run where id=p_run_id for update;
  if r.id is null or r.user_id<>p_user_id or r.connection_id<>p_connection_id or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  select * into c from public.lts_open_finance_connection where id=p_connection_id and user_id=p_user_id and provider='pluggy' and institution_code='341';
  if c.id is null then raise exception 'INVALID_CONNECTION'; end if;
  if p_records is null or jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)>100 then raise exception 'INVALID_BATCH'; end if;
  for x in select value from jsonb_array_elements(p_records) loop
    if x->>'provider_record_id' not like c.provider_connection_ref||':%' or x->>'raw_hash' !~ '^[0-9a-f]{64}$'
      or x->'normalized_payload'->>'item_id' is distinct from c.provider_connection_ref then raise exception 'INVALID_RECORD_SCOPE'; end if;
    if exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id') then
      if not exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' and raw_hash=x->>'raw_hash' and raw_payload=x->'raw_payload' and normalized_payload=x->'normalized_payload' and reconciliation=x->'reconciliation') then raise exception 'RETRY_PAYLOAD_CHANGED'; end if;
      continue;
    end if;
    classification:=x->'reconciliation'->>'classification';
    if classification is null or classification not in ('exact','candidate','new','conflict') then raise exception 'INVALID_RECONCILIATION'; end if;
    stage_status:=case classification when 'exact' then 'matched_exact' when 'candidate' then 'matched_candidate' when 'conflict' then 'blocked' else 'normalized' end;
    select * into old from public.lts_open_finance_staging where user_id=p_user_id and provider='pluggy' and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' for update;
    action:=case when old.id is null then 'inserted' when old.raw_hash=x->>'raw_hash' then 'unchanged'
      when old.provider_updated_at is not null and nullif(x->>'provider_updated_at','')::timestamptz<old.provider_updated_at then 'stale' else 'updated' end;
    if old.id is not null and old.connection_id<>p_connection_id then raise exception 'RECORD_CONNECTION_MISMATCH'; end if;
    insert into public.lts_open_finance_observation(user_id,connection_id,sync_run_id,resource_type,provider_record_id,raw_hash,raw_payload,normalized_payload,reconciliation,ingest_action)
    values(p_user_id,p_connection_id,p_run_id,x->>'resource_type',x->>'provider_record_id',x->>'raw_hash',x->'raw_payload',x->'normalized_payload',x->'reconciliation',action);
    if action<>'stale' then
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
    end if;
    n:=n+1;
  end loop;
  return jsonb_build_object('observations_inserted',n,'promotion_enabled',false);
end $function$;

CREATE OR REPLACE FUNCTION public.lts_open_finance_stage_batch_bank_v1(p_user_id uuid, p_connection_id uuid, p_run_id uuid, p_records jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run; c public.lts_open_finance_connection;
  x jsonb; old public.lts_open_finance_staging; classification text; action text; stage_status text; n integer:=0;
begin
  select * into r from public.lts_open_finance_sync_run where id=p_run_id for update;
  if r.id is null or r.user_id<>p_user_id or r.connection_id<>p_connection_id or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  select * into c from public.lts_open_finance_connection where id=p_connection_id and user_id=p_user_id and provider='pluggy' and institution_code in ('237','336');
  if c.id is null then raise exception 'INVALID_CONNECTION'; end if;
  if p_records is null or jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)>100 then raise exception 'INVALID_BATCH'; end if;
  for x in select value from jsonb_array_elements(p_records) loop
    if x->>'provider_record_id' not like c.provider_connection_ref||':%' or x->>'raw_hash' !~ '^[0-9a-f]{64}$'
      or x->'normalized_payload'->>'item_id' is distinct from c.provider_connection_ref then raise exception 'INVALID_RECORD_SCOPE'; end if;
    if exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id') then
      if not exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' and raw_hash=x->>'raw_hash' and raw_payload=x->'raw_payload' and normalized_payload=x->'normalized_payload' and reconciliation=x->'reconciliation') then raise exception 'RETRY_PAYLOAD_CHANGED'; end if;
      continue;
    end if;
    classification:=x->'reconciliation'->>'classification';
    if classification is null or classification not in ('exact','candidate','new','conflict') then raise exception 'INVALID_RECONCILIATION'; end if;
    stage_status:=case classification when 'exact' then 'matched_exact' when 'candidate' then 'matched_candidate' when 'conflict' then 'blocked' else 'normalized' end;
    select * into old from public.lts_open_finance_staging where user_id=p_user_id and provider='pluggy' and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' for update;
    action:=case when old.id is null then 'inserted' when old.raw_hash=x->>'raw_hash' then 'unchanged'
      when old.provider_updated_at is not null and nullif(x->>'provider_updated_at','')::timestamptz<old.provider_updated_at then 'stale' else 'updated' end;
    if old.id is not null and old.connection_id<>p_connection_id then raise exception 'RECORD_CONNECTION_MISMATCH'; end if;
    insert into public.lts_open_finance_observation(user_id,connection_id,sync_run_id,resource_type,provider_record_id,raw_hash,raw_payload,normalized_payload,reconciliation,ingest_action)
    values(p_user_id,p_connection_id,p_run_id,x->>'resource_type',x->>'provider_record_id',x->>'raw_hash',x->'raw_payload',x->'normalized_payload',x->'reconciliation',action);
    if action<>'stale' then
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
    end if;
    n:=n+1;
  end loop;
  return jsonb_build_object('observations_inserted',n,'promotion_enabled',false);
end $function$;
