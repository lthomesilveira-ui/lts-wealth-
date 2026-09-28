-- Preserve financial calculations; share the existing source-invalidated future cache.
CREATE TEMP TABLE lts_v225_live_before(key text PRIMARY KEY, value jsonb) ON COMMIT DROP;
INSERT INTO lts_v225_live_before VALUES
('planning',public.lts_planning_executive_v2(public.lts_open_finance_pilot_owner_v1(),current_date,make_date(extract(year from current_date)::int+1,12,31))),
('flow',public.lts_current_flow_v225(public.lts_open_finance_pilot_owner_v1(),current_date,make_date(extract(year from current_date)::int+1,12,31)));
CREATE OR REPLACE FUNCTION public.lts_browser_planning_executive_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1();
begin return public.lts_planning_executive_v2(u,current_date,make_date(extract(year from current_date)::int+1,12,31)); end $function$
;

CREATE OR REPLACE FUNCTION public.lts_current_flow_v225(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  raw jsonb; position jsonb; first_day jsonb; days jsonb; events jsonb;
  delta_i numeric; delta_b numeric; delta_c numeric;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date or p_to-current_date>12000 then
    raise exception 'invalid current/future range';
  end if;
  raw:=case when p_to+30<=current_date+1800 then public.lts_flow_future_read_slice_v9(p_user_id,current_date,p_to) else public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to) end;
  position:=public.lts_open_finance_current_bank_position_v1(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from public.lts_dashboard_cash_ladder_from_flow_v2(p_user_id,current_date,p_to,raw)
  ), adjusted as (
    select (d->>'date')::date dt,
      d || jsonb_build_object(
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+delta_i+delta_b+delta_c,
          'saldo_final',l.operational_cash,
          'liq_d0_1_recurso',l.d01_resource,
          'rsus_vested',l.rsu_vested_scheduled,
          'fgts',l.fgts_projected,
          'saldo_apos_d0_1',l.balance_after_d01,
          'saldo_apos_rsu',l.balance_with_scheduled_vesting,
          'saldo_apos_fgts',l.balance_with_fgts_projected,
          'liq_d0_1',l.balance_after_d01,
          'posicao_antes_rsus',l.balance_after_d01,
          'disponivel_total',l.balance_with_scheduled_vesting,
          'posicao_curto_prazo',l.balance_with_scheduled_vesting
        )
      ) value
    from jsonb_array_elements(raw->'days') d join layers l on l.flow_date=(d->>'date')::date
    where (d->>'date')::date between p_from and p_to
  ) select jsonb_agg(value order by dt) into days from adjusted;
  if jsonb_array_length(days)<>p_to-p_from+1 then raise exception 'incomplete current/future days'; end if;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into events
    from jsonb_array_elements(coalesce(raw->'events','[]'::jsonb)) e
    where (e->>'event_date')::date between p_from and p_to;
  return raw||jsonb_build_object('from',p_from,'to',p_to,'days',days,'events',events,
    'version','daily-flow-v225-current-anchors','current_anchor_date',current_date);
end
$function$
;

CREATE OR REPLACE FUNCTION public.lts_flow_future_read_cache_refresh_v9(p_user_id uuid, p_days integer DEFAULT 730)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare d1 date:=current_date; d2 date:=current_date+least(1800,greatest(730,coalesce(p_days,730),coalesce((select to_date-current_date from public.lts_flow_future_read_cache_v2 where user_id=p_user_id and as_of=current_date),0))); j jsonb; t0 timestamptz:=clock_timestamp();
begin
  j:=public.lts_daily_flow_fix86_v20(p_user_id,d1,d2);
  insert into public.lts_flow_future_read_cache_v2(user_id,as_of,from_date,to_date,engine_version,payload,refreshed_at)
  values(p_user_id,d1,d1,d2,j->>'version',j,now())
  on conflict(user_id) do update set as_of=excluded.as_of,from_date=excluded.from_date,to_date=excluded.to_date,
    engine_version=excluded.engine_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return jsonb_build_object('ok',true,'as_of',d1,'to',d2,'days',jsonb_array_length(coalesce(j->'days','[]'::jsonb)),
    'events',jsonb_array_length(coalesce(j->'events','[]'::jsonb)),'engine_version',j->>'version',
    'elapsed_ms',round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1));
end
$function$
;

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
;

CREATE OR REPLACE FUNCTION public.lts_open_finance_begin_itau_v1(p_user_id uuid, p_item_id text, p_item jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c public.lts_open_finance_connection; r public.lts_open_finance_sync_run;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
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
end $function$
;

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
;

CREATE OR REPLACE FUNCTION public.lts_planning_executive_v2(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT '2027-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with f as (select case when p_from>=current_date and p_to+30<=current_date+1800 then public.lts_flow_future_read_slice_v9(p_user_id,p_from,p_to) else public.lts_daily_flow_fix86_v20(p_user_id,p_from,p_to) end j),
l as (select public.lts_planning_liquidity_ladder_v2(p_user_id,p_from,p_to,f.j) j from f)
select jsonb_build_object('version','planning-executive-v2-current-anchors','period',jsonb_build_object('from',p_from,'to',p_to),
'summary',jsonb_build_object('first_real_gap_date',l.j->'first_real_gap_date','fgts_request_by',l.j#>'{fgts_access,request_by_date}','fgts_amount',l.j#>'{fgts_access,amount_brl}','fgts_covers_horizon',l.j#>'{fgts_access,covers_horizon_if_available}','first_negative_even_with_fgts',l.j#>'{fgts_access,first_negative_even_with_fgts}'),
'layers',l.j->'layers','fgts_access',l.j->'fgts_access','guardrails',jsonb_build_array('Current cash is anchored to Open Finance.','D0 uses validated Cofrinho.','Morgan available uses validated total including brokerage cash.','Future vestings enter only after availability.','FGTS is D+30 contingency and horizon rupture is assessed after applicable liquidity layers.')) from l
$function$
;

CREATE OR REPLACE FUNCTION public.lts_refresh_product_read_cache_operational_v5_legacy_20260926(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  base_result jsonb;
  flow_result jsonb;
begin
  base_result := public.lts_refresh_product_read_cache_operational_v4(p_user_id);
  flow_result := public.lts_flow_future_read_cache_refresh_v9(p_user_id, 730);
  return jsonb_build_object(
    'ok', coalesce((base_result->>'ok')::boolean, false) and coalesce((flow_result->>'ok')::boolean, false),
    'version', 'operational-refresh-v8-flow-v20-cache',
    'base_refresh', base_result,
    'flow_v20_refresh', flow_result
  );
end
$function$
;

SELECT public.lts_flow_future_read_cache_refresh_v9(public.lts_open_finance_pilot_owner_v1(),730);
DO $guard$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); j jsonb; old_flow jsonb; before_days jsonb; after_days jsonb; keys text[]:=array['saldo_anterior','saldo_final','liq_d0_1_recurso','rsus_vested','fgts','saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'];
BEGIN
 IF (SELECT value FROM lts_v225_live_before WHERE key='planning') IS DISTINCT FROM public.lts_planning_executive_v2(u,current_date,make_date(extract(year from current_date)::int+1,12,31)) THEN RAISE EXCEPTION 'planning calculation changed'; END IF;
 SELECT value INTO old_flow FROM lts_v225_live_before WHERE key='flow';
 j:=public.lts_current_flow_v225(u,current_date,make_date(extract(year from current_date)::int+1,12,31));
 SELECT jsonb_agg(jsonb_build_object('date',d->'date','Itaú',d#>'{Itaú,balance}','Bradesco',d#>'{Bradesco,balance}','C6',d#>'{C6,balance}','columns',(SELECT jsonb_object_agg(k,d->'fix86_columns'->k) FROM unnest(keys) k)) ORDER BY d->>'date') INTO before_days FROM jsonb_array_elements(old_flow->'days') d;
 SELECT jsonb_agg(jsonb_build_object('date',d->'date','Itaú',d#>'{Itaú,balance}','Bradesco',d#>'{Bradesco,balance}','C6',d#>'{C6,balance}','columns',(SELECT jsonb_object_agg(k,d->'fix86_columns'->k) FROM unnest(keys) k)) ORDER BY d->>'date') INTO after_days FROM jsonb_array_elements(j->'days') d;
 IF before_days IS DISTINCT FROM after_days OR old_flow->'events' IS DISTINCT FROM j->'events' THEN RAISE EXCEPTION 'flow financial values or events changed'; END IF;
 IF NOT (public.lts_current_cash_release_qa_v1()->>'pass')::boolean OR NOT (public.lts_planning_ui_release_qa_v1()->>'pass')::boolean THEN RAISE EXCEPTION 'financial gate changed'; END IF;
 IF has_function_privilege('anon','public.lts_browser_flow_v13(date,date)','EXECUTE') OR has_function_privilege('authenticated','public.lts_current_flow_v225(uuid,date,date)','EXECUTE') THEN RAISE EXCEPTION 'access boundary changed'; END IF;
END $guard$;

