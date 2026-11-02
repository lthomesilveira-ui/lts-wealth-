CREATE OR REPLACE FUNCTION public.lts_open_finance_begin_bank_v1(p_user_id uuid, p_item_id text, p_item jsonb, p_request_id uuid, p_institution_code text, p_institution_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c public.lts_open_finance_connection; r public.lts_open_finance_sync_run;
begin
 if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
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
end $function$
