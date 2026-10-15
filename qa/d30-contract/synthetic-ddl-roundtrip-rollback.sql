BEGIN;
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
CREATE OR REPLACE FUNCTION public.lts_current_flow_v229(p_user_id uuid, p_from date, p_to date)
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
  raw:=case when p_to+30<=current_date+1800 then public.lts_flow_future_read_slice_v9(p_user_id,current_date,p_to) else public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to+30) end;
  position:=public.lts_open_finance_current_bank_position_v1(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id,current_date,p_to,raw)
  ), daily_totals as materialized (
    select (x->>'date')::date dt,count(*) row_count,
      count(nullif(x#>>'{Consolidado,economic_net}','')) known_count,
      sum(nullif(x#>>'{Consolidado,economic_net}','')::numeric) economic_net
    from jsonb_array_elements(raw->'days')x group by 1
  ), future_windows as materialized (
    select dt,count(*) over w future_dates,sum(row_count) over w future_rows,
      sum(known_count) over w known_movements,sum(economic_net) over w future_net
    from daily_totals
    window w as (order by dt range between interval '1 day' following and interval '30 days' following)
  ), adjusted as (
    select (d->>'date')::date dt,
      d || jsonb_build_object(
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i,'opening_balance',coalesce((d#>>'{Itaú,opening_balance}')::numeric,(d#>>'{Itaú,balance}')::numeric-(d#>>'{Itaú,net}')::numeric)+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b,'opening_balance',coalesce((d#>>'{Bradesco,opening_balance}')::numeric,(d#>>'{Bradesco,balance}')::numeric-(d#>>'{Bradesco,net}')::numeric)+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c,'opening_balance',coalesce((d#>>'{C6,opening_balance}')::numeric,(d#>>'{C6,balance}')::numeric-(d#>>'{C6,net}')::numeric)+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+l.operational_cash-(d#>>'{fix86_columns,saldo_final}')::numeric,
          'saldo_final',l.operational_cash,
          'liq_d0_1_recurso',l.d01_resource,
          'rsus_vested',l.rsu_vested_scheduled,
          'fgts',l.fgts_projected,
          'saldo_apos_d0_1',l.balance_after_d01,
          'saldo_apos_rsu',l.balance_with_scheduled_vesting,
          'saldo_apos_fgts',l.balance_with_fgts_projected,
          'liq_d0_1',l.balance_after_d01,
          -- Short branch already includes next30 economic movements. Re-anchor
          -- only its eligible D0 basis. Long branch obtains the missing lookahead.
          'liq_d30',CASE WHEN p_to+30<=current_date+1800 THEN
            (d#>>'{fix86_columns,liq_d30}')::numeric+l.balance_after_d01-(d#>>'{fix86_columns,liq_d0_1}')::numeric
          ELSE CASE WHEN w.future_dates=30 AND w.future_rows=30 AND w.known_movements=30 THEN l.balance_after_d01+w.future_net ELSE NULL END END,
          'posicao_antes_rsus',l.balance_after_d01,
          'disponivel_total',l.balance_with_scheduled_vesting,
          'posicao_curto_prazo',l.balance_with_scheduled_vesting
        )
      ) value
    from jsonb_array_elements(raw->'days') d join layers l on l.flow_date=(d->>'date')::date left join future_windows w on w.dt=(d->>'date')::date
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
CREATE OR REPLACE FUNCTION public.lts_flow_future_read_slice_v9(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer; source_key text; horizon_end date;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1800 then raise exception 'future range exceeds supported horizon'; end if;
  source_key:=public.lts_flow_read_source_key_v247(p_user_id);
  select * into c from public.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    if current_setting('transaction_read_only')::boolean then
      -- Same engine, horizon and fingerprint as refresh_v9. No source writes.
      horizon_end:=current_date+least(1800,greatest(60,requested_horizon,
        coalesce((select to_date-current_date from public.lts_flow_future_read_cache_v2
          where user_id=p_user_id and as_of=current_date),0)));
      select p_user_id user_id,current_date as_of,current_date from_date,horizon_end to_date,
        'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'::text engine_version,
        public.lts_daily_flow_fix86_v20(p_user_id,current_date,horizon_end)
          ||jsonb_build_object('source_fingerprint',source_key) payload,now() refreshed_at into c;
    else
      perform public.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
      select * into c from public.lts_flow_future_read_cache_v2
       where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
         and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
       order by refreshed_at desc limit 1;
    end if;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=public.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.lts_card_invoice_amounts_v230(p_user_id)i where (i.status='open' OR (i.status='projected' AND i.source='derived_installments_v234')) and i.due_date>=current_date));
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',coalesce(to_jsonb(
      CASE WHEN (SELECT count(*)=30 AND count(DISTINCT y.dt)=30 AND count(nullif(y.x#>>'{Consolidado,economic_net}',''))=30 FROM all_src y WHERE y.dt>s.dt AND y.dt<=s.dt+30)
      THEN nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric+(
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30) ELSE NULL END),'null'::jsonb),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$
;
DO $$ BEGIN
 IF md5(pg_get_functiondef('public.lts_current_flow_v229(uuid,date,date)'::regprocedure)) IS DISTINCT FROM '87e67d199a57d9c947c792faac147ad7' THEN RAISE EXCEPTION 'DDL roundtrip mismatch: lts_current_flow_v229(uuid,date,date)'; END IF;
 IF md5(pg_get_functiondef('public.lts_flow_future_read_slice_v9(uuid,date,date)'::regprocedure)) IS DISTINCT FROM 'ab9dc5d78cbbc116600f9f233268a032' THEN RAISE EXCEPTION 'DDL roundtrip mismatch: lts_flow_future_read_slice_v9(uuid,date,date)'; END IF;
END $$;
SELECT 'PASS: candidate public DDL canonical hashes; disposable database only; no source readers executed' AS test_result;
ROLLBACK;
