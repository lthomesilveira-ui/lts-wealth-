BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
CREATE TEMP TABLE movements(offset_day integer PRIMARY KEY, economic_net numeric);
INSERT INTO movements SELECT n,CASE n WHEN 1 THEN 10 WHEN 30 THEN -17 WHEN 31 THEN -1000 ELSE 0 END FROM generate_series(0,12030)n;
CREATE TEMP TABLE fixture_rows AS
 SELECT n.offset_day,jsonb_build_object('date',current_date+n.offset_day,
 'Itaú',jsonb_build_object('balance',100+c.net,'net',n.economic_net),
 'Bradesco',jsonb_build_object('balance',200,'net',0),
 'C6',jsonb_build_object('balance',300,'net',0),
 'Consolidado',jsonb_build_object('bank_balance',600+c.net,'economic_net',n.economic_net),
 'fix86_columns',jsonb_build_object('saldo_anterior',600+c.net-n.economic_net,'saldo_final',600+c.net,'liq_d0_1_recurso',50,'liq_d0_1',650+c.net,
 'liq_d30',650+c.net+(SELECT sum(m.economic_net) FROM movements m WHERE m.offset_day>n.offset_day AND m.offset_day<=n.offset_day+30))) AS row
 FROM (SELECT *,sum(economic_net) OVER(ORDER BY offset_day ROWS UNBOUNDED PRECEDING) net FROM movements)n CROSS JOIN LATERAL(SELECT n.net)c;
CREATE FUNCTION pg_temp.fixture_slice(uuid,date,date) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('days',(SELECT jsonb_agg(row ORDER BY offset_day) FROM pg_temp.fixture_rows WHERE offset_day BETWEEN 0 AND $3-current_date),'events','[]'::jsonb) $$;
CREATE FUNCTION pg_temp.fixture_daily(uuid,date,date) RETURNS jsonb LANGUAGE sql AS $$ SELECT pg_temp.fixture_slice($1,$2,$3) $$;
CREATE FUNCTION pg_temp.fixture_position(uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"accounts":[{"institution_code":"341","balance":200},{"institution_code":"237","balance":200},{"institution_code":"336","balance":300}]}'::jsonb $$;
CREATE FUNCTION pg_temp.fixture_ladder(uuid,date,date,jsonb) RETURNS TABLE(flow_date date,operational_cash numeric,d01_resource numeric,balance_after_d01 numeric,rsu_vested_scheduled numeric,fgts_projected numeric,balance_with_scheduled_vesting numeric,balance_with_fgts_projected numeric) LANGUAGE sql AS $$
 SELECT (d->>'date')::date,(d#>>'{fix86_columns,saldo_final}')::numeric+100,100::numeric,(d#>>'{fix86_columns,liq_d0_1}')::numeric+150,20::numeric,30::numeric,(d#>>'{fix86_columns,liq_d0_1}')::numeric+170,(d#>>'{fix86_columns,liq_d0_1}')::numeric+200 FROM jsonb_array_elements($4->'days')d $$;
CREATE OR REPLACE FUNCTION pg_temp.current_flow_under_test(p_user_id uuid, p_from date, p_to date)
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
  raw:=case when p_to+30<=current_date+1800 then pg_temp.fixture_slice(p_user_id,current_date,p_to) else pg_temp.fixture_daily(p_user_id,current_date,p_to+30) end;
  position:=pg_temp.fixture_position(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from pg_temp.fixture_ladder(p_user_id,current_date,p_to,raw)
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
DO $$ DECLARE result jsonb; started timestamptz:=clock_timestamp(); elapsed numeric; failures integer; BEGIN
 result:=pg_temp.current_flow_under_test('00000000-0000-0000-0000-000000000001',current_date,current_date+12000);
 elapsed:=extract(epoch FROM clock_timestamp()-started);
 IF jsonb_array_length(result->'days') IS DISTINCT FROM 12001 THEN RAISE EXCEPTION 'full supported horizon truncated'; END IF;
 SELECT count(*) INTO failures FROM jsonb_array_elements(result->'days')d
 WHERE (d#>>'{fix86_columns,liq_d30}')::numeric IS DISTINCT FROM
  (d#>>'{fix86_columns,liq_d0_1}')::numeric+(SELECT sum(economic_net) FROM pg_temp.movements WHERE offset_day>(d->>'date')::date-current_date AND offset_day<=(d->>'date')::date-current_date+30);
 IF failures IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'full-horizon mismatches:%',failures; END IF;
 IF (result#>>'{days,12000,fix86_columns,liq_d30}')::numeric IS DISTINCT FROM -207 THEN RAISE EXCEPTION 'tail lookahead mismatch'; END IF;
 RAISE NOTICE 'candidate reader full12001days synthetic elapsed_seconds=%',elapsed;
END $$;
SELECT 'PASS: full12001-day candidate with30extra synthetic dates; dependency cost is not production performance' AS test_result;
ROLLBACK;
