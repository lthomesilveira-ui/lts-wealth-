CREATE OR REPLACE FUNCTION public.lts_open_finance_finish_bank_v1(p_user_id uuid, p_run_id uuid, p_status text, p_metadata jsonb, p_error_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run;c public.lts_open_finance_connection;cnt int;
begin
 if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
 select * into r from public.lts_open_finance_sync_run where id=p_run_id for update;if not found or r.user_id<>p_user_id then raise exception 'RUN_OWNER_MISMATCH';end if;
 select count(*) into cnt from public.lts_open_finance_observation where sync_run_id=p_run_id;
 update public.lts_open_finance_sync_run set status=p_status,finished_at=now(),raw_count=cnt,normalized_count=cnt,promoted_count=0,error_code=p_error_code,metadata=coalesce(metadata,'{}')||coalesce(p_metadata,'{}') where id=p_run_id returning * into r;
 select * into c from public.lts_open_finance_connection where id=r.connection_id;
 update public.lts_open_finance_connection set last_error_code=p_error_code,last_error_summary=case when p_error_code is null then null else 'Sincronização não concluída; tente novamente.' end,last_attempt_at=now(),last_success_at=case when p_status in ('success','partial') then now() else last_success_at end,status=case when p_status in ('success','partial') then 'connected' else status end where id=c.id;
 return jsonb_build_object('run_id',r.id,'connection_id',r.connection_id,'status',r.status,'raw_count',r.raw_count,'normalized_count',r.normalized_count,'promoted_count',0,'error_code',r.error_code,'metadata',r.metadata);
end $function$
