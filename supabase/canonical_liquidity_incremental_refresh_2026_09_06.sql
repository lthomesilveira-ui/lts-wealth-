-- LTS Wealth canonical incremental liquidity refresh — 2026-09-06
-- Source-of-truth sync for the already-tested Supabase runtime state.
-- Financial contract: bank↔D0 movement is equal-and-opposite, excluded from spend,
-- and has economic_effect_brl = 0. Public index.html is not part of this package.

CREATE OR REPLACE FUNCTION public.lts_patch_flow_liquidity_movement_v1(p_user_id uuid, p_flow jsonb, p_move jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_preview jsonb:=coalesce(p_move->'preview',p_move,'{}'::jsonb);
  v_event_date date;
  v_bank numeric;
  v_asset numeric;
  v_account text;
  v_move_id uuid;
  v_event_id uuid;
  v_days jsonb:='[]'::jsonb;
  v_events jsonb;
  v_day jsonb;
  v_dt date;
  v_acc jsonb;
  v_cons jsonb;
  v_summary jsonb;
  v_sum_cons jsonb;
  v_fix jsonb;
  v_event jsonb;
  v_from date;
  v_to date;
begin
  if coalesce(p_flow->>'version','')<>'daily-flow-fix86-v13-bank-asset-liquidity-parity' then
    raise exception 'incremental liquidity patch requires Flow v13 cache';
  end if;
  begin v_event_date:=(v_preview->>'event_date')::date; exception when others then raise exception 'valid preview event_date required'; end;
  begin v_bank:=(v_preview->>'bank_delta_brl')::numeric; exception when others then raise exception 'valid preview bank_delta_brl required'; end;
  begin v_asset:=(v_preview->>'asset_delta_brl')::numeric; exception when others then raise exception 'valid preview asset_delta_brl required'; end;
  v_account:=nullif(trim(v_preview->>'account'),'');
  if v_account is null or v_account not in ('Itaú','Bradesco','C6') then raise exception 'supported preview account required'; end if;
  if round(v_bank+v_asset,2)<>0 then raise exception 'bank/asset deltas must net to zero'; end if;
  begin v_move_id:=(p_move->>'movement_id')::uuid; exception when others then raise exception 'movement_id required'; end;
  begin v_event_id:=(p_move->>'bank_event_id')::uuid; exception when others then raise exception 'bank_event_id required'; end;
  perform 1 from public.lts_liquidity_movement m where m.id=v_move_id and m.user_id=p_user_id and m.bank_event_id=v_event_id and m.status='active';
  if not found then raise exception 'active liquidity movement not found'; end if;

  begin v_from:=(p_flow->>'from')::date; exception when others then v_from:=null; end;
  begin v_to:=(p_flow->>'to')::date; exception when others then v_to:=null; end;

  for v_day in select value from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) loop
    v_dt:=(v_day->>'date')::date;
    if v_dt>=v_event_date then
      v_acc:=coalesce(v_day->v_account,'{}'::jsonb);
      v_acc:=v_acc||jsonb_build_object(
        'balance',round(coalesce((v_acc->>'balance')::numeric,0)+v_bank,2),
        'net',round(coalesce((v_acc->>'net')::numeric,0)+case when v_dt=v_event_date then v_bank else 0 end,2)
      );
      v_day:=jsonb_set(v_day,array[v_account],v_acc,true);

      v_cons:=coalesce(v_day->'Consolidado','{}'::jsonb)||jsonb_build_object(
        'bank_balance',round(coalesce((v_day#>>'{Consolidado,bank_balance}')::numeric,0)+v_bank,2)
      );
      v_day:=jsonb_set(v_day,'{Consolidado}',v_cons,true);

      -- Flow v13 base already places the bank event in transfer-in-transit and
      -- v13 neutralizes it. The cached v13 payload is already neutralized.

      v_fix:=coalesce(v_day->'fix86_columns','{}'::jsonb);
      v_fix:=v_fix||jsonb_build_object(
        'saldo_anterior',round(coalesce((v_fix->>'saldo_anterior')::numeric,0)+case when v_dt>v_event_date then v_bank else 0 end,2),
        'saldo_final',round(coalesce((v_fix->>'saldo_final')::numeric,0)+v_bank,2),
        'liq_d0_1_recurso',round(coalesce((v_fix->>'liq_d0_1_recurso')::numeric,0)+v_asset,2),
        'cash_semantics','bank cash includes bank↔asset movements; D0 asset leg is equal/opposite and economic spend remains excluded'
      );
      if v_dt=v_event_date then
        v_fix:=v_fix||jsonb_build_object(
          'entradas',round(coalesce((v_fix->>'entradas')::numeric,0)+greatest(v_bank,0),2),
          'saidas',round(coalesce((v_fix->>'saidas')::numeric,0)+greatest(-v_bank,0),2),
          'liquidity_movement_net_cash',round(coalesce((v_fix->>'liquidity_movement_net_cash')::numeric,0)+v_bank,2),
          'liquidity_movement_count',coalesce((v_fix->>'liquidity_movement_count')::int,0)+1
        );
        v_summary:=coalesce(v_day->'summary','{}'::jsonb);
        v_sum_cons:=coalesce(v_summary->'Consolidado','{}'::jsonb)||jsonb_build_object(
          'entries',round(coalesce((v_summary#>>'{Consolidado,entries}')::numeric,0)+greatest(v_bank,0),2),
          'exits',round(coalesce((v_summary#>>'{Consolidado,exits}')::numeric,0)+greatest(-v_bank,0),2)
        );
        v_summary:=v_summary||jsonb_build_object(
          'asset_movements',coalesce((v_summary->>'asset_movements')::int,0)+1,
          'Consolidado',v_sum_cons
        );
        v_day:=jsonb_set(v_day,'{summary}',v_summary,true);
      end if;
      v_day:=jsonb_set(v_day,'{fix86_columns}',v_fix,true);
    end if;
    v_days:=v_days||jsonb_build_array(v_day);
  end loop;

  v_event:=jsonb_build_object(
    'source','liquidity_movement','account',v_account,'category','Movimentação de liquidez','displaced',false,
    'confidence','user_reviewed','event_date',v_event_date,'source_ref','financial_events:'||v_event_id::text,
    'center_cost',null,'description',v_preview->>'description','counterparty',v_preview->>'asset_name','legacy_index',null,
    'original_date',v_event_date,'signed_amount',v_bank,'semantic_rule_id',null,'internal_transfer',false,
    'is_asset_movement',true,'account_assignment','assigned','excluded_from_spend',true,
    'movement_type',v_preview->>'movement_type','liquidity_movement_id',v_move_id
  );
  if (v_from is null or v_event_date>=v_from) and (v_to is null or v_event_date<=v_to) then
    select coalesce(jsonb_agg(value order by (value->>'event_date')::date,coalesce(value->>'source',''),coalesce(value->>'description','')),'[]'::jsonb)
      into v_events
    from jsonb_array_elements(coalesce(p_flow->'events','[]'::jsonb)||jsonb_build_array(v_event));
  else
    v_events:=coalesce(p_flow->'events','[]'::jsonb);
  end if;

  return jsonb_set(jsonb_set(p_flow,'{days}',v_days,true),'{events}',v_events,true)
    ||jsonb_build_object('incremental_liquidity_patch','v1-flow13-cache-delta');
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_refresh_after_liquidity_movement_v4(p_user_id uuid, p_move jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_payload jsonb;
  v_future_flow jsonb;
  v_flow_annual jsonb;
  v_flow_short jsonb;
  v_plan_exec jsonb;
  v_dashboard jsonb;
  v_planning jsonb;
  v_plan_ladder jsonb;
  v_wealth jsonb;
  v_future_row public.lts_flow_future_read_cache_v2%rowtype;
  v_cockpit jsonb;
  v_preview jsonb:=coalesce(p_move->'preview',p_move,'{}'::jsonb);
  v_event_date date;
  v_bank numeric;
  v_asset numeric;
  v_horizon date:=(current_date+interval '12 months')::date;
  t0 timestamptz:=clock_timestamp();
  ms numeric;
begin
  begin v_event_date:=(v_preview->>'event_date')::date; exception when others then raise exception 'valid movement event_date required'; end;
  begin v_bank:=(v_preview->>'bank_delta_brl')::numeric; exception when others then raise exception 'valid bank_delta_brl required'; end;
  begin v_asset:=(v_preview->>'asset_delta_brl')::numeric; exception when others then raise exception 'valid asset_delta_brl required'; end;
  if round(v_bank+v_asset,2)<>0 then raise exception 'liquidity movement must be economically neutral'; end if;

  select * into v_future_row from public.lts_flow_future_read_cache_v2 where user_id=p_user_id for update;
  if not found or v_future_row.as_of<>current_date or v_future_row.from_date>current_date or v_future_row.to_date<v_horizon
     or v_future_row.engine_version<>'daily-flow-fix86-v13-bank-asset-liquidity-parity' then
    return public.lts_refresh_after_liquidity_movement_v2(p_user_id)||jsonb_build_object('fast_path',false,'fallback_reason','future Flow v13 cache unavailable/stale');
  end if;

  v_future_flow:=public.lts_patch_flow_liquidity_movement_v1(p_user_id,v_future_row.payload,p_move);
  v_flow_annual:=public.lts_flow_slice_from_payload_v1(v_future_flow,current_date,v_horizon);
  v_flow_short:=public.lts_flow_slice_from_payload_v1(v_future_flow,current_date,current_date+42);
  v_plan_exec:=public.lts_planning_executive_from_flow_v1(p_user_id,current_date,v_horizon,v_flow_annual);
  v_dashboard:=public.lts_dashboard_executive_from_flow_v1(p_user_id,current_date,v_flow_annual);
  v_planning:=public.lts_cashflow_scenarios_from_flow_v1(p_user_id,current_date,make_date(extract(year from current_date)::int,12,31),v_flow_annual);
  v_plan_ladder:=jsonb_build_object(
    'version','planning-liquidity-ladder-v5-flow-v13-effective-liquidity','from',v_plan_exec#>'{period,from}','to',v_plan_exec#>'{period,to}',
    'flow_basis','lts_daily_flow_fix86_v13','layers',v_plan_exec->'layers','first_real_gap_date',v_plan_exec#>'{summary,first_real_gap_date}',
    'gap_episodes',v_plan_exec->'gap_episodes','fgts_first_negative_date',v_plan_exec#>'{summary,first_negative_even_with_fgts}',
    'fgts_access',v_plan_exec->'fgts_access','guardrail','Uses incrementally patched Flow v13 after a reviewed bank↔asset movement. Economic liquidity is unchanged; bank/D0 composition is updated.'
  );

  select payload into v_payload from public.lts_product_read_cache where user_id=p_user_id and payload_version='lts-product-fix86-v36' for update;
  if v_payload is null then
    return public.lts_refresh_after_liquidity_movement_v2(p_user_id)||jsonb_build_object('fast_path',false,'fallback_reason','product cache unavailable');
  end if;
  v_wealth:=v_payload->'wealth_executive';
  if coalesce(v_wealth->>'reconciliation_version','')<>'wealth-summary-current-effective-v1' then
    v_wealth:=public.lts_wealth_executive_report_v5(p_user_id);
  elsif v_event_date<=current_date then
    v_wealth:=jsonb_set(v_wealth,'{liquidity}',coalesce(v_wealth->'liquidity','{}'::jsonb)||jsonb_build_object(
      'bank_cash',round(coalesce((v_wealth#>>'{liquidity,bank_cash}')::numeric,0)+v_bank,2),
      'd0',round(coalesce((v_wealth#>>'{liquidity,d0}')::numeric,0)+v_asset,2)
    ),true);
    v_wealth:=jsonb_set(v_wealth,'{effective_liquidity_movement}',coalesce(v_wealth->'effective_liquidity_movement','{}'::jsonb)||jsonb_build_object(
      'active_movements_through_today',coalesce((v_wealth#>>'{effective_liquidity_movement,active_movements_through_today}')::int,0)+1,
      'bank_asset_parity',true,'read_basis','incremental Flow v13 cache + effective D0 delta'
    ),true);
  end if;

  v_payload:=v_payload||jsonb_build_object(
    'flow',v_flow_short,'planning',v_planning,'planning_ladder',v_plan_ladder,'planning_executive',v_plan_exec,
    'dashboard',v_dashboard,'wealth_executive',v_wealth,
    'wealth',public.lts_wealth_current_patch_v1(p_user_id,v_payload->'wealth')
  );
  update public.lts_product_read_cache set payload=v_payload,refreshed_at=now(),source='liquidity_movement_refresh_v4_incremental_flow13' where user_id=p_user_id;

  update public.lts_flow_future_read_cache_v2 set payload=v_future_flow,engine_version=v_future_flow->>'version',refreshed_at=now() where user_id=p_user_id;
  delete from public.lts_dashboard_cockpit_cache where user_id=p_user_id;
  v_cockpit:=public.lts_refresh_dashboard_cockpit_v1(p_user_id);
  ms:=round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1);
  return jsonb_build_object(
    'ok',true,'version','liquidity-movement-refresh-v4-incremental-flow13','fast_path',true,
    'flow_version',v_future_flow->>'version','planning_ladder_version',v_plan_ladder->>'version','wealth_version',v_wealth->>'version',
    'dashboard_cockpit_version',v_cockpit->>'version','elapsed_ms',ms,'economic_effect_brl',0,'financial_fact_changed',false,
    'guardrail','Reuses the audited 730-day Flow v13 cache, patches only the reviewed equal-and-opposite bank/D0 delta, and recomputes Planning/Dashboard from that patched Flow.'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_liquidity_incremental_refresh_case_qa_v1(p_user_id uuid, p_type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_type text:=lower(trim(p_type));
  v_account text;
  v_asset_id uuid;
  v_key text:='qa-liq-inc-'||v_type||'-'||gen_random_uuid()::text;
  v_base_future jsonb;
  v_base_product jsonb;
  v_move jsonb;
  v_patched jsonb;
  v_live jsonb;
  v_refresh jsonb;
  v_days_ok boolean:=false;
  v_event_ok boolean:=false;
  v_plan_ok boolean:=false;
  v_dash_ok boolean:=false;
  v_cache_ok boolean:=false;
  v_rollback_ok boolean:=false;
  v_rows int;
  v_event_rows int;
  v_move_id text;
  v_bank_delta numeric;
  v_asset_delta numeric;
  v_base_bank numeric;
  v_base_d0 numeric;
begin
  if v_type not in ('application','redemption') then raise exception 'type must be application or redemption'; end if;
  select institution into v_account from public.accounts where user_id=p_user_id and is_active=true order by case when lower(institution) in ('itaú','itau') then 0 else 1 end,institution limit 1;
  select asset_position_id into v_asset_id from public.lts_asset_position_effective_v1(p_user_id,current_date) where asset_type='cash_investment' and is_available_now order by asset_name limit 1;
  select payload into v_base_future from public.lts_flow_future_read_cache_v2 where user_id=p_user_id;
  select payload into v_base_product from public.lts_product_read_cache where user_id=p_user_id;
  select coalesce((x#>>'{Consolidado,bank_balance}')::numeric,0),coalesce((x#>>'{fix86_columns,liq_d0_1_recurso}')::numeric,0)
  into v_base_bank,v_base_d0 from jsonb_array_elements(coalesce(v_base_product#>'{flow,days}','[]'::jsonb)) x where x->>'date'=current_date::text limit 1;
  if v_account is null or v_asset_id is null or coalesce(v_base_future->>'version','')<>'daily-flow-fix86-v13-bank-asset-liquidity-parity' then
    return jsonb_build_object('type',v_type,'pass',false,'error','eligible account/asset or Flow v13 cache missing');
  end if;

  begin
    v_move:=public.lts_apply_liquidity_movement_v2(p_user_id,jsonb_build_object(
      'movement_type',v_type,'amount_brl',100,'event_date',current_date,'account',v_account,'asset_position_id',v_asset_id,
      'description','QA incremental '||v_type||' rollback','approved',true),v_key);
    v_move_id:=v_move->>'movement_id';
    v_bank_delta:=(v_move#>>'{preview,bank_delta_brl}')::numeric;
    v_asset_delta:=(v_move#>>'{preview,asset_delta_brl}')::numeric;
    v_patched:=public.lts_patch_flow_liquidity_movement_v1(p_user_id,v_base_future,v_move);
    v_live:=public.lts_daily_flow_fix86_v13(p_user_id,current_date,current_date+730);

    select bool_and(
      (p.value->v_account)=(l.value->v_account)
      and (p.value->'Consolidado')=(l.value->'Consolidado')
      and (p.value->'summary')=(l.value->'summary')
      and (p.value->'fix86_columns')=(l.value->'fix86_columns')
      and (p.value->'Transferências em trânsito')=(l.value->'Transferências em trânsito')
    ) into v_days_ok
    from jsonb_array_elements(v_patched->'days') p(value)
    join jsonb_array_elements(v_live->'days') l(value) on p.value->>'date'=l.value->>'date';

    select exists(
      select 1 from jsonb_array_elements(coalesce(v_patched->'events','[]'::jsonb)) e
      where e->>'source'='liquidity_movement' and e->>'liquidity_movement_id'=v_move_id
        and coalesce((e->>'signed_amount')::numeric,0)=v_bank_delta
        and coalesce((e->>'is_asset_movement')::boolean,false)=true
        and coalesce((e->>'excluded_from_spend')::boolean,false)=true
    ) into v_event_ok;

    v_plan_ok:=public.lts_planning_executive_from_flow_v1(p_user_id,current_date,(current_date+interval '12 months')::date,public.lts_flow_slice_from_payload_v1(v_patched,current_date,(current_date+interval '12 months')::date))
      =public.lts_planning_executive_from_flow_v1(p_user_id,current_date,(current_date+interval '12 months')::date,public.lts_flow_slice_from_payload_v1(v_live,current_date,(current_date+interval '12 months')::date));
    v_dash_ok:=public.lts_dashboard_executive_from_flow_v1(p_user_id,current_date,public.lts_flow_slice_from_payload_v1(v_patched,current_date,(current_date+interval '12 months')::date))
      =public.lts_dashboard_executive_from_flow_v1(p_user_id,current_date,public.lts_flow_slice_from_payload_v1(v_live,current_date,(current_date+interval '12 months')::date));

    v_refresh:=public.lts_refresh_after_liquidity_movement_v4(p_user_id,v_move);
    select abs(coalesce((c.payload#>>'{wealth_executive,liquidity,bank_cash}')::numeric,0)-(v_base_bank+v_bank_delta))<=0.01
      and abs(coalesce((c.payload#>>'{wealth_executive,liquidity,d0}')::numeric,0)-(v_base_d0+v_asset_delta))<=0.01
      and c.source='liquidity_movement_refresh_v4_incremental_flow13'
    into v_cache_ok from public.lts_product_read_cache c where c.user_id=p_user_id;

    raise exception using errcode='P9204',message='qa_liq_incremental_case_rollback';
  exception when sqlstate 'P9204' then null;
  end;

  select count(*) into v_rows from public.lts_liquidity_movement where user_id=p_user_id and idempotency_key=v_key;
  select count(*) into v_event_rows from public.financial_events where user_id=p_user_id and metadata->>'idempotency_key'=v_key;
  v_rollback_ok:=v_rows=0 and v_event_rows=0;

  return (
    with checks as (
      select * from (values
        ('flow_days_equivalent',v_days_ok),
        ('movement_event_contract',v_event_ok),
        ('planning_equivalent',v_plan_ok),
        ('dashboard_equivalent',v_dash_ok),
        ('fast_refresh_cache_contract',v_cache_ok),
        ('rollback_clean',v_rollback_ok)
      ) v(id,pass)
    )
    select jsonb_build_object('type',v_type,'pass',bool_and(pass),'total',count(*),'passed',count(*) filter(where pass),'failed',count(*) filter(where not pass),'checks',jsonb_agg(jsonb_build_object('id',id,'pass',pass) order by id),'fast_refresh_elapsed_ms',v_refresh->'elapsed_ms') from checks
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_liquidity_incremental_refresh_qa_v2(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare a jsonb; r jsonb;
begin
  a:=public.lts_liquidity_incremental_refresh_case_qa_v1(p_user_id,'application');
  r:=public.lts_liquidity_incremental_refresh_case_qa_v1(p_user_id,'redemption');
  return jsonb_build_object(
    'version','liquidity-incremental-refresh-qa-v2-bidirectional',
    'pass',coalesce((a->>'pass')::boolean,false) and coalesce((r->>'pass')::boolean,false),
    'application',a,'redemption',r,
    'guardrail','Application and redemption are both executed inside rollback-clean subtransactions and compared against the full Flow v13/Planning/Dashboard engine.'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_apply_liquidity_movement_v1(p_preview jsonb, p_idempotency_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  u uuid;
  d date;
  j jsonb;
  r jsonb;
begin
  u:=public.lts_browser_assert_user_v1();
  begin d:=coalesce(nullif(p_preview->>'event_date','')::date,current_date); exception when others then raise exception 'valid event_date required'; end;
  if d<current_date then raise exception 'browser liquidity writer currently supports today/future movements only'; end if;
  j:=public.lts_apply_liquidity_movement_v2(u,p_preview,p_idempotency_key);
  if coalesce((j->>'idempotent')::boolean,false) then
    r:=jsonb_build_object(
      'ok',true,'version','liquidity-movement-refresh-v4-incremental-flow13','fast_path',true,
      'idempotent_refresh_skipped',true,'economic_effect_brl',0,
      'guardrail','The original idempotent movement was already committed with its atomic cache refresh; the same key never applies the delta twice.'
    );
  else
    r:=public.lts_refresh_after_liquidity_movement_v4(u,j);
  end if;
  return j||jsonb_build_object('refresh',r,'browser_version','liquidity-movement-browser-v3-incremental-flow13-refresh');
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_liquidity_movement_contract_qa_v1()
RETURNS jsonb
LANGUAGE sql
SET search_path TO 'public'
AS $function$
with defs as (
  select proname,pg_get_functiondef(p.oid) def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('lts_browser_flow_v5','lts_browser_wealth_executive_v3','lts_browser_liquidity_movement_options_v1','lts_browser_preview_liquidity_movement_v1','lts_browser_apply_liquidity_movement_v1')
), checks as (
  select * from (values
    ('flow_v5_authenticated',has_function_privilege('authenticated','public.lts_browser_flow_v5(date,date)','EXECUTE'),'auth execute'),
    ('flow_v5_anon_blocked',not has_function_privilege('anon','public.lts_browser_flow_v5(date,date)','EXECUTE'),'anon blocked'),
    ('wealth_v3_authenticated',has_function_privilege('authenticated','public.lts_browser_wealth_executive_v3()','EXECUTE'),'auth execute'),
    ('wealth_v3_anon_blocked',not has_function_privilege('anon','public.lts_browser_wealth_executive_v3()','EXECUTE'),'anon blocked'),
    ('options_authenticated',has_function_privilege('authenticated','public.lts_browser_liquidity_movement_options_v1()','EXECUTE'),'auth execute'),
    ('options_anon_blocked',not has_function_privilege('anon','public.lts_browser_liquidity_movement_options_v1()','EXECUTE'),'anon blocked'),
    ('preview_authenticated',has_function_privilege('authenticated','public.lts_browser_preview_liquidity_movement_v1(jsonb)','EXECUTE'),'auth execute'),
    ('preview_anon_blocked',not has_function_privilege('anon','public.lts_browser_preview_liquidity_movement_v1(jsonb)','EXECUTE'),'anon blocked'),
    ('apply_authenticated',has_function_privilege('authenticated','public.lts_browser_apply_liquidity_movement_v1(jsonb,text)','EXECUTE'),'auth execute'),
    ('apply_anon_blocked',not has_function_privilege('anon','public.lts_browser_apply_liquidity_movement_v1(jsonb,text)','EXECUTE'),'anon blocked'),
    ('internal_preview_blocked',not has_function_privilege('authenticated','public.lts_preview_liquidity_movement_v2(uuid,jsonb)','EXECUTE'),'arbitrary user blocked'),
    ('internal_apply_blocked',not has_function_privilege('authenticated','public.lts_apply_liquidity_movement_v2(uuid,jsonb,text)','EXECUTE'),'arbitrary user blocked'),
    ('internal_fast_refresh_blocked',not has_function_privilege('authenticated','public.lts_refresh_after_liquidity_movement_v4(uuid,jsonb)','EXECUTE'),'arbitrary user blocked'),
    ('table_auth_blocked',not has_table_privilege('authenticated','public.lts_liquidity_movement','SELECT'),'no direct table read'),
    ('table_anon_blocked',not has_table_privilege('anon','public.lts_liquidity_movement','SELECT'),'no direct table read'),
    ('all_browser_wrappers_assert_user',(select bool_and(def like '%lts_browser_assert_user_v1%') from defs),'auth.uid scoped wrappers'),
    ('apply_uses_incremental_refresh',(select def like '%lts_refresh_after_liquidity_movement_v4%' from defs where proname='lts_browser_apply_liquidity_movement_v1'),'write→incremental Flow v13/Planning/Dashboard/Wealth/future cache/cockpit refresh v4'),
    ('apply_idempotent_delta_guard',(select def like '%idempotent_refresh_skipped%' from defs where proname='lts_browser_apply_liquidity_movement_v1'),'same idempotency key never patches the cache twice'),
    ('preview_rejects_past_browser_dates',(select def like '%today/future movements only%' from defs where proname='lts_browser_preview_liquidity_movement_v1'),'historical path not exposed yet')
  ) v(id,pass,evidence)
)
select jsonb_build_object('version','browser-liquidity-movement-contract-qa-v3-incremental-refresh','pass',bool_and(pass),'total',count(*),'passed',count(*) filter(where pass),'failed',count(*) filter(where not pass),'checks',jsonb_agg(jsonb_build_object('id',id,'pass',pass,'evidence',evidence) order by id),'guardrail','Browser exposure is auth.uid-scoped, anon-blocked and cannot call arbitrary-user internal writers. Apply uses the rollback-proven incremental Flow v13 refresh; repeated idempotency keys cannot double-apply the cache delta. Historical liquidity writes remain blocked.') from checks;
$function$;

REVOKE ALL ON FUNCTION public.lts_patch_flow_liquidity_movement_v1(uuid,jsonb,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lts_refresh_after_liquidity_movement_v4(uuid,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lts_liquidity_incremental_refresh_case_qa_v1(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lts_liquidity_incremental_refresh_qa_v2(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_apply_liquidity_movement_v1(jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_apply_liquidity_movement_v1(jsonb,text) TO authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_liquidity_movement_contract_qa_v1() FROM PUBLIC, anon, authenticated;
