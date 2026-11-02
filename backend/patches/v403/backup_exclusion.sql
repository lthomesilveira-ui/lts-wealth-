DO $guard$ BEGIN
IF position('v403-backup-sync-exclusion' IN pg_get_functiondef('public.lts_open_finance_begin_bank_v1(uuid,text,jsonb,uuid,text,text)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_begin_bank_v1(uuid,text,jsonb,uuid,text,text)'::regprocedure))<>'e0ae9cab95d7ca9a30f8148ae4d11f49' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_begin_bank_v1';END IF;
IF position('v403-backup-sync-exclusion' IN pg_get_functiondef('public.lts_open_finance_begin_itau_v1(uuid,text,jsonb,uuid)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_begin_itau_v1(uuid,text,jsonb,uuid)'::regprocedure))<>'cf23d863954fb208ddf8d498e573e57f' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_begin_itau_v1';END IF;
IF position('v403-backup-sync-exclusion' IN pg_get_functiondef('public.lts_open_finance_enqueue_bank_v1(text,text)'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_open_finance_enqueue_bank_v1(text,text)'::regprocedure))<>'dec5637186afa0a3ec4e941580b2fc39' THEN RAISE EXCEPTION 'V403 source changed: lts_open_finance_enqueue_bank_v1';END IF;
IF position('v403-backup-sync-exclusion' IN pg_get_functiondef('public.lts_recover_stale_bank_sync_v245()'::regprocedure))=0 AND md5(pg_get_functiondef('public.lts_recover_stale_bank_sync_v245()'::regprocedure))<>'5fe99350c33422f6d7d654a13c8d0bec' THEN RAISE EXCEPTION 'V403 source changed: lts_recover_stale_bank_sync_v245';END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_begin_bank_v1(p_user_id uuid, p_item_id text, p_item jsonb, p_request_id uuid, p_institution_code text, p_institution_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c public.lts_open_finance_connection; r public.lts_open_finance_sync_run;
begin
 if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
 -- v403-backup-sync-exclusion
 if not pg_try_advisory_xact_lock_shared(hashtextextended('lts-maintenance-v403:'||p_user_id::text,0)) then
  raise exception 'BACKUP_IN_PROGRESS_RETRY_LATER';
 end if;
 if p_institution_code not in ('237','336') then raise exception 'UNSUPPORTED_BANK'; end if;
 if p_item_id !~ '^[0-9a-fA-F-]{36}$' or p_item->>'id' is distinct from p_item_id or p_item->>'status' is distinct from 'UPDATED' or p_item->>'executionStatus' is distinct from 'SUCCESS' then raise exception 'INVALID_ITEM_BINDING'; end if;
 perform pg_advisory_xact_lock(hashtextextended('lts-open-finance-bank:'||p_institution_code||':'||p_user_id::text,0));
 if exists(select 1 from public.lts_open_finance_connection where user_id=p_user_id and provider='pluggy' and institution_code=p_institution_code and provider_connection_ref<>p_item_id and status not in ('disabled','revoked')) then raise exception 'PILOT_ALREADY_BOUND_TO_DIFFERENT_ITEM'; end if;
 insert into public.lts_open_finance_connection(user_id,provider,provider_connection_ref,institution_code,institution_name,connection_mode,scopes,status,consent_expires_at,metadata)
 values(p_user_id,'pluggy',p_item_id,p_institution_code,p_institution_name,'meupluggy_proxy',coalesce(p_item->'products','[]'::jsonb),'connected',nullif(p_item->>'consentExpiresAt','')::timestamptz,jsonb_build_object('pilot','multibank_shadow_v1','item',p_item,'promotion_enabled',false))
 on conflict(user_id,provider,provider_connection_ref) do update set institution_code=excluded.institution_code,institution_name=excluded.institution_name,scopes=excluded.scopes,status='connected',consent_expires_at=excluded.consent_expires_at,metadata=lts_open_finance_connection.metadata||excluded.metadata,updated_at=now()
 returning * into c;
 update public.lts_open_finance_sync_run set status='failed',finished_at=now(),error_code='STALE_RUN_RECOVERED',error_summary='Execution exceeded the lease; safe to retry.' where connection_id=c.id and status='running' and started_at<now()-interval '10 minutes';
 select * into r from public.lts_open_finance_sync_run where id=p_request_id;
 if found then if r.user_id<>p_user_id or r.connection_id<>c.id then raise exception 'RUN_OWNER_MISMATCH'; end if; return jsonb_build_object('connection_id',c.id,'run_id',r.id,'existing',true,'status',r.status); end if;
 if exists(select 1 from public.lts_open_finance_sync_run where connection_id=c.id and status='running') then raise exception 'SYNC_ALREADY_RUNNING'; end if;
 insert into public.lts_open_finance_sync_run(id,user_id,connection_id,trigger_type,status,metadata)
 values(p_request_id,p_user_id,c.id,'manual','running',jsonb_build_object('version','pluggy-multibank-shadow-v1','institution_code',p_institution_code,'item_updated_at',p_item->>'lastUpdatedAt','promotion_enabled',false));
 update public.lts_open_finance_connection set last_attempt_at=now(),last_error_code=null,last_error_summary=null where id=c.id;
 return jsonb_build_object('connection_id',c.id,'run_id',p_request_id,'existing',false,'status','running');
end $function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_begin_itau_v1(p_user_id uuid, p_item_id text, p_item jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c public.lts_open_finance_connection; r public.lts_open_finance_sync_run;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
 -- v403-backup-sync-exclusion
 if not pg_try_advisory_xact_lock_shared(hashtextextended('lts-maintenance-v403:'||p_user_id::text,0)) then
  raise exception 'BACKUP_IN_PROGRESS_RETRY_LATER';
 end if;
  if p_item_id !~ '^[0-9a-fA-F-]{36}$' or p_item->>'id' is distinct from p_item_id
    or p_item->>'status' is distinct from 'UPDATED' or p_item->>'executionStatus' is distinct from 'SUCCESS' then raise exception 'INVALID_ITEM_BINDING'; end if;
  perform pg_advisory_xact_lock(hashtextextended('lts-open-finance-itau:'||p_user_id::text,0));
  if exists(select 1 from public.lts_open_finance_connection where user_id=p_user_id and provider='pluggy'
    and institution_code='341' and provider_connection_ref<>p_item_id and status not in ('disabled','revoked')) then
    raise exception 'PILOT_ALREADY_BOUND_TO_DIFFERENT_ITEM';
  end if;
  insert into public.lts_open_finance_connection(user_id,provider,provider_connection_ref,institution_code,institution_name,connection_mode,scopes,status,consent_expires_at,metadata)
  values(p_user_id,'pluggy',p_item_id,'341','Itaú','meupluggy_proxy',coalesce(p_item->'products','[]'::jsonb),'connected',
    nullif(p_item->>'consentExpiresAt','')::timestamptz,jsonb_build_object('pilot','itau_shadow_v1','item',p_item,'promotion_enabled',false))
  on conflict(user_id,provider,provider_connection_ref) do update set
    scopes=excluded.scopes,status='connected',consent_expires_at=excluded.consent_expires_at,
    metadata=lts_open_finance_connection.metadata||excluded.metadata,updated_at=now()
  returning * into c;
  -- Recover abandoned executions; no provider records or financial facts are removed.
  update public.lts_open_finance_sync_run set status='failed',finished_at=now(),error_code='STALE_RUN_RECOVERED',
    error_summary='Execution exceeded the lease; safe to retry.' where connection_id=c.id and status='running' and started_at<now()-interval '10 minutes';
  select * into r from public.lts_open_finance_sync_run where id=p_request_id;
  if found then
    if r.user_id<>p_user_id or r.connection_id<>c.id then raise exception 'RUN_OWNER_MISMATCH'; end if;
    return jsonb_build_object('connection_id',c.id,'run_id',r.id,'existing',true,'status',r.status);
  end if;
  if exists(select 1 from public.lts_open_finance_sync_run where connection_id=c.id and status='running') then raise exception 'SYNC_ALREADY_RUNNING'; end if;
  insert into public.lts_open_finance_sync_run(id,user_id,connection_id,trigger_type,status,metadata)
  values(p_request_id,p_user_id,c.id,'manual','running',jsonb_build_object('version','pluggy-itau-shadow-v1','item_updated_at',p_item->>'lastUpdatedAt','promotion_enabled',false));
  update public.lts_open_finance_connection set last_attempt_at=now(),last_error_code=null,last_error_summary=null where id=c.id;
  return jsonb_build_object('connection_id',c.id,'run_id',p_request_id,'existing',false,'status','running');
end $function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_enqueue_bank_v1(p_code text, p_action text DEFAULT 'sync'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid; nonce text; jid uuid; req bigint;
begin
 if p_code not in ('341','237','336') or p_action not in ('sync','discover') then raise exception 'INVALID'; end if;
 uid:=public.lts_open_finance_pilot_owner_v1();
 -- v403-backup-sync-exclusion
 if not pg_try_advisory_xact_lock_shared(hashtextextended('lts-maintenance-v403:'||uid::text,0)) then
  return jsonb_build_object('ok',true,'deferred',true,'reason','backup_in_progress','institution_code',p_code);
 end if;
 nonce:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.lts_open_finance_job(user_id,action,token_hash,expires_at) values(uid,p_action,encode(extensions.digest(nonce,'sha256'),'hex'),now()+interval '5 minutes') returning id into jid;
 select net.http_post(url:='https://tadhkamnwtsbdozwkyut.supabase.co/functions/v1/lts-open-finance-itau',body:=jsonb_build_object('action',p_action,'institution_code',p_code),headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer internal-job','x-lts-of-job',nonce),timeout_milliseconds:=180000) into req;
 update public.lts_open_finance_job set http_request_id=req where id=jid;
 return jsonb_build_object('job_id',jid,'http_request_id',req,'institution_code',p_code);
end $function$;
CREATE OR REPLACE FUNCTION public.lts_recover_stale_bank_sync_v245()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE uid uuid:=public.lts_open_finance_pilot_owner_v1(); code text; requested jsonb;
BEGIN
 IF NOT pg_try_advisory_xact_lock(hashtextextended('lts-of-recovery-v245',0)) THEN
  RETURN jsonb_build_object('ok',true,'already_running',true); END IF;
 SELECT c.institution_code INTO code FROM public.lts_open_finance_connection c
 WHERE c.user_id=uid AND c.provider='pluggy' AND c.status='connected'
 AND c.institution_code IN('341','237','336')
 AND (c.consent_expires_at IS NULL OR c.consent_expires_at>clock_timestamp())
 AND coalesce(c.last_success_at,'epoch'::timestamptz)<clock_timestamp()-interval '70 minutes'
 AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_sync_run r WHERE r.connection_id=c.id
  AND r.status='running' AND r.started_at>clock_timestamp()-interval '10 minutes')
 AND NOT EXISTS(SELECT 1 FROM public.lts_of_recovery_attempt_v245 a WHERE a.institution_code=c.institution_code
  AND a.requested_at>clock_timestamp()-interval '10 minutes')
 ORDER BY c.last_success_at NULLS FIRST,c.institution_code LIMIT 1;
 IF code IS NULL THEN RETURN jsonb_build_object('ok',true,'requested',false);END IF;
 requested:=public.lts_open_finance_enqueue_bank_v1(code,'sync');
 -- v403-backup-sync-exclusion
 IF coalesce((requested->>'deferred')::boolean,false) THEN RETURN requested||jsonb_build_object('requested',false);END IF;
 INSERT INTO public.lts_of_recovery_attempt_v245(institution_code,http_request_id)
 VALUES(code,(requested->>'http_request_id')::bigint);
 RETURN jsonb_build_object('ok',true,'requested',true,'institution_code',code);
END $function$;

-- V401 already bounds the connection to 90s and validates the 33-table manifest.
-- This small scheduler gate preserves that writer and all historical bundles.
CREATE OR REPLACE FUNCTION public.lts_backup_scheduled_v403(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog SET TimeZone='America/Sao_Paulo' AS $function$
DECLARE d date:=current_date; s public.lts_backup_supplement_v380%rowtype;result jsonb;
BEGIN
 IF p_user_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.usuario WHERE id=p_user_id) THEN RAISE EXCEPTION 'unknown user';END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('lts-maintenance-v403:'||p_user_id::text,0)) THEN
  RAISE LOG 'LTS_BACKUP_V403_DEFERRED active_sync_transaction';
  RETURN jsonb_build_object('ok',false,'deferred',true,'reason','active_sync_transaction','snapshot_date',d);
 END IF;
 SELECT * INTO s FROM public.lts_backup_supplement_v380 WHERE user_id=p_user_id AND snapshot_date=d;
 IF FOUND THEN
  RETURN jsonb_build_object('ok',true,'inserted',false,'already_complete',true,'snapshot_date',d,
   'payload_sha256',s.payload_sha256,'payload_bytes',s.payload_bytes,'counts',s.counts);
 END IF;
 IF EXISTS(SELECT 1 FROM public.lts_open_finance_sync_run WHERE user_id=p_user_id AND status='running')
 OR EXISTS(SELECT 1 FROM public.lts_open_finance_job WHERE user_id=p_user_id AND consumed_at IS NULL AND expires_at>clock_timestamp()) THEN
  RAISE LOG 'LTS_BACKUP_V403_DEFERRED active_or_queued_sync';
  RETURN jsonb_build_object('ok',false,'deferred',true,'reason','active_or_queued_sync','snapshot_date',d);
 END IF;
 result:=public.lts_backup_snapshot_take_v380(p_user_id,d);
 RETURN result||jsonb_build_object('writer_revision','v401','scheduler_revision','v403','exclusion_guard',true);
END $function$;
REVOKE ALL ON FUNCTION public.lts_backup_scheduled_v403(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_scheduled_v403(uuid) TO service_role;

DO $schedule$
DECLARE j record;expected text;next_command text;cnt integer:=0;
BEGIN
 FOR j IN SELECT * FROM cron.job WHERE jobname='lts_daily_backup_snapshot' LOOP
  cnt:=cnt+1;
  IF j.command LIKE '%lts_backup_scheduled_v403(%' THEN
   IF j.schedule<>'35,40,50,55 6 * * *' OR NOT j.active THEN RAISE EXCEPTION 'V403 schedule drift';END IF;
   CONTINUE;
  END IF;
  IF j.schedule<>'15 6 * * *' OR NOT j.active OR j.command !~ $rx$^SET statement_timeout = '90s'; select public\.lts_backup_snapshot_take_v380\('[0-9a-f-]{36}'::uuid,current_date\);$rx$ THEN
   RAISE EXCEPTION 'Unexpected backup job; no schedule changed';
  END IF;
  next_command:=replace(j.command,'lts_backup_snapshot_take_v380','lts_backup_scheduled_v403');
  next_command:=replace(next_command,'::uuid,current_date','::uuid');
  -- 03:35/03:40/03:50/03:55 Sao Paulo. Hourly bank sync remains :15.
  -- Stop after the first successful daily capture; later attempts are metadata-only.
  PERFORM cron.alter_job(j.jobid,schedule:='35,40,50,55 6 * * *',command:=next_command);
 END LOOP;
 IF cnt<>1 THEN RAISE EXCEPTION 'Expected one backup job';END IF;
END $schedule$;
