BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
CREATE TEMP TABLE fixture_cache(user_id uuid,as_of date,from_date date,to_date date,payload jsonb,engine_version text,refreshed_at timestamptz);
CREATE TEMP TABLE seed_data(payload jsonb,refresh_calls integer);
INSERT INTO seed_data SELECT jsonb_build_object('source_fingerprint','synthetic-key','events','[]'::jsonb,'days',jsonb_agg(jsonb_build_object('date',current_date+n,'Consolidado',jsonb_build_object('economic_net',CASE n WHEN 0 THEN -99 WHEN 1 THEN 10 WHEN 30 THEN -17 WHEN 31 THEN -1000 ELSE 0 END),'fix86_columns',jsonb_build_object('liq_d0_1',650)) ORDER BY n)),0 FROM generate_series(0,61)n;
CREATE FUNCTION pg_temp.source_key(uuid) RETURNS text LANGUAGE sql AS $$ SELECT 'synthetic-key'::text $$;
CREATE FUNCTION pg_temp.overlay(jsonb,jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT $1 $$;
CREATE FUNCTION pg_temp.invoices(uuid) RETURNS TABLE(status text,source text,due_date date) LANGUAGE sql AS $$ SELECT NULL::text,NULL::text,NULL::date WHERE false $$;
CREATE FUNCTION pg_temp.fixture_daily(uuid,date,date) RETURNS jsonb LANGUAGE sql AS $$ SELECT payload FROM pg_temp.seed_data $$;
CREATE FUNCTION pg_temp.fixture_refresh(uuid,integer) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 UPDATE pg_temp.seed_data SET refresh_calls=refresh_calls+1;
 INSERT INTO pg_temp.fixture_cache SELECT $1,current_date,current_date,current_date+61,payload,'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181',clock_timestamp() FROM pg_temp.seed_data;
END $$;
CREATE OR REPLACE FUNCTION pg_temp.slice_under_test(p_user_id uuid, p_from date, p_to date)
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
  source_key:=pg_temp.source_key(p_user_id);
  select * into c from pg_temp.fixture_cache
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    if current_setting('transaction_read_only')::boolean then
      -- Same engine, horizon and fingerprint as refresh_v9. No source writes.
      horizon_end:=current_date+least(1800,greatest(60,requested_horizon,
        coalesce((select to_date-current_date from pg_temp.fixture_cache
          where user_id=p_user_id and as_of=current_date),0)));
      select p_user_id user_id,current_date as_of,current_date from_date,horizon_end to_date,
        'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'::text engine_version,
        pg_temp.fixture_daily(p_user_id,current_date,horizon_end)
          ||jsonb_build_object('source_fingerprint',source_key) payload,now() refreshed_at into c;
    else
      perform pg_temp.fixture_refresh(p_user_id,requested_horizon);
      select * into c from pg_temp.fixture_cache
       where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
         and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
       order by refreshed_at desc limit 1;
    end if;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=pg_temp.overlay(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from pg_temp.invoices(p_user_id)i where (i.status='open' OR (i.status='projected' AND i.source='derived_installments_v234')) and i.due_date>=current_date));
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
DO $$ DECLARE result jsonb; uid uuid:='00000000-0000-0000-0000-000000000001'; BEGIN
 result:=pg_temp.slice_under_test(uid,current_date,current_date);
 IF result#>>'{days,0,fix86_columns,liq_d30}' IS DISTINCT FROM '643' THEN RAISE EXCEPTION 'cold short window mismatch'; END IF;
 IF (SELECT refresh_calls FROM pg_temp.seed_data) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'cold did not refresh exactly once'; END IF;
 result:=pg_temp.slice_under_test(uid,current_date,current_date);
 IF result#>>'{days,0,fix86_columns,liq_d30}' IS DISTINCT FROM '643' OR (SELECT refresh_calls FROM pg_temp.seed_data) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'warm parity failed'; END IF;
 UPDATE pg_temp.fixture_cache SET payload=jsonb_set(payload,'{days,30,Consolidado,economic_net}','null'::jsonb);
 result:=pg_temp.slice_under_test(uid,current_date,current_date);
 IF result#>'{days,0,fix86_columns,liq_d30}' IS DISTINCT FROM 'null'::jsonb OR result#>>'{days,0,date}' IS DISTINCT FROM current_date::text THEN RAISE EXCEPTION 'NULL movement must preserve row with unknown D30'; END IF;
 UPDATE pg_temp.fixture_cache SET payload=(SELECT payload FROM pg_temp.seed_data);
 UPDATE pg_temp.fixture_cache SET payload=jsonb_set(payload,'{days,0,fix86_columns}','{}'::jsonb);
 result:=pg_temp.slice_under_test(uid,current_date,current_date);
 IF result#>'{days,0,fix86_columns,liq_d30}' IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'missing D0 became zero'; END IF;
 UPDATE pg_temp.fixture_cache SET payload=(SELECT payload FROM pg_temp.seed_data);
 UPDATE pg_temp.fixture_cache SET payload=jsonb_set(payload,'{days,30}',payload#>'{days,29}');
 result:=pg_temp.slice_under_test(uid,current_date,current_date);
 IF result#>'{days,0,fix86_columns,liq_d30}' IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'duplicate concealed missing date'; END IF;
END $$;
SELECT 'PASS: candidate slice9 exact body cold/warm, D+30 bounds, NULL movement/D0, duplicate coverage; synthetic dependencies only' AS test_result;
ROLLBACK;
