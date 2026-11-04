CREATE OR REPLACE FUNCTION public.lts_open_finance_finish_itau_v1(p_user_id uuid, p_run_id uuid, p_status text, p_metadata jsonb, p_error_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run; stats jsonb;
begin
  select * into r from public.lts_open_finance_sync_run where id=p_run_id and user_id=p_user_id for update;
  if r.id is null or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  if p_status is null or p_status not in ('success','partial','failed') then raise exception 'INVALID_SYNC_STATUS'; end if;
  if p_error_code is not null and p_error_code !~ '^[A-Z0-9_]{1,80}$' then raise exception 'INVALID_ERROR_CODE'; end if;
  select jsonb_build_object('total',count(*),'exact',count(*) filter(where reconciliation->>'classification'='exact'),
    'candidate',count(*) filter(where reconciliation->>'classification'='candidate'),'new',count(*) filter(where reconciliation->>'classification'='new'),
    'conflict',count(*) filter(where reconciliation->>'classification'='conflict'),
    'inserted',count(*) filter(where ingest_action='inserted'),'updated',count(*) filter(where ingest_action='updated'),
    'unchanged',count(*) filter(where ingest_action='unchanged'),'stale',count(*) filter(where ingest_action='stale')) into stats
  from public.lts_open_finance_observation where sync_run_id=p_run_id and user_id=p_user_id;
  if p_status='success' and ((stats->>'total')::int=0 or coalesce((p_metadata->>'expected_count')::int,-1)<>(stats->>'total')::int
    or exists(select 1 from jsonb_array_elements(coalesce(p_metadata->'coverage','[]')) x where x->>'status'='unavailable')) then raise exception 'INCOMPLETE_SUCCESS_NOT_ALLOWED'; end if;
  update public.lts_open_finance_sync_run set status=p_status,finished_at=now(),raw_count=(stats->>'total')::int,normalized_count=(stats->>'total')::int,
    exact_match_count=(stats->>'exact')::int,candidate_match_count=(stats->>'candidate')::int,blocked_count=(stats->>'conflict')::int,promoted_count=0,
    error_code=p_error_code,error_summary=case when p_error_code is not null then 'Shadow sync incomplete; see safe error code.' end,
    metadata=metadata||p_metadata||jsonb_build_object('counts',stats,'promotion_enabled',false) where id=p_run_id;
  update public.lts_open_finance_connection set last_success_at=case when p_status='success' then now() else last_success_at end,
    last_error_code=p_error_code,last_error_summary=case when p_error_code is not null then 'Shadow sync incomplete.' end,updated_at=now() where id=r.connection_id;
  return jsonb_build_object('run_id',p_run_id,'status',p_status,'counts',stats,'promotion_enabled',false);
end $function$
