BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL jit=off;
SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE proof_v255(kind text,input jsonb,prior jsonb,prior_ms numeric) ON COMMIT DROP;
CREATE TEMP TABLE acl_v255 AS SELECT proacl::text acl FROM pg_proc WHERE oid='public.lts_flow_documentary_bank_sum_v237(uuid,jsonb)'::regprocedure;
DO $baseline$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); r record;j jsonb;f jsonb;v jsonb;t timestamptz;
BEGIN
 FOR r IN SELECT * FROM(VALUES('current_next'::text,date '2026-01-01',date '2027-12-31'),('july_boundary',date '2026-06-30',date '2026-07-14'),('historical_2019_2020',date '2019-01-01',date '2020-12-31')) x(k,lo,hi) LOOP
  j:=public.lts_browser_flow_pre_v248(r.lo,r.hi);
  f:=public.lts_flow_bounded_workbook_positions_v238(u,public.lts_flow_workbook_positions_v248(u,j->'flow'));
  t:=clock_timestamp();v:=public.lts_flow_documentary_bank_sum_v237(u,f);
  INSERT INTO proof_v255 VALUES(r.k,f,v,round(extract(epoch from clock_timestamp()-t)*1000,3));
 END LOOP;
END $baseline$;
-- V255: exact per-day documentary sums, without recomputing the arrays for each day.
DO $v255$
DECLARE s text:=pg_get_functiondef('public.lts_flow_documentary_bank_sum_v237(uuid,jsonb)'::regprocedure);needle text;
BEGIN
 IF md5(btrim(s,E' \t\r\n'))<>'7f651e68c7aa0b88d5a6245231884555' THEN RAISE EXCEPTION 'V255_SOURCE_LEASE_CHANGED';END IF;
 needle:=$old0$base_itau numeric;base_bradesco numeric;$old0$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_0_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new0$base_itau numeric;base_bradesco numeric;cash_daily_v255 jsonb;event_daily_v255 jsonb;$new0$);
 needle:=$old1$ FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP$old1$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_1_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new1$ -- Aggregate the same documentary movement rows once. No dates, sources,
 -- identities, anchor decisions, account balances or unknowns are changed.
 WITH rows_v255 AS MATERIALIZED (
  SELECT h->>'event_date' dt,h->>'account' bank,(h->>'signed_amount')::numeric amount
  FROM jsonb_array_elements(cash) h
 ), daily_v255 AS (
  SELECT r.dt,r.bank,coalesce(sum(r.amount) FILTER(WHERE r.amount>0),0) income,
   coalesce(-sum(r.amount) FILTER(WHERE r.amount<0),0) expense
  FROM rows_v255 r GROUP BY r.dt,r.bank
 )
 SELECT coalesce(jsonb_object_agg(a.dt||'|'||a.bank,jsonb_build_object('income',a.income,'expense',a.expense)),'{}')
 INTO cash_daily_v255 FROM daily_v255 a WHERE a.dt IS NOT NULL AND a.bank IS NOT NULL;
 WITH day_keys_v255 AS MATERIALIZED (
  SELECT DISTINCT (day.x->>'date')||'|'||b.bank k
  FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]')) day(x)
  CROSS JOIN unnest(ARRAY['Itaú','Bradesco','C6']) b(bank)
  WHERE (day.x->>'date')::date>date '2026-08-23'
   AND (day.x->b.bank)->>'balance' IS NOT NULL
   AND (day.x->b.bank)->>'balance_basis' IS DISTINCT FROM 'relative_tracked_bank_ledger'
 ), rows_v255 AS MATERIALIZED (
  SELECT h->>'event_date' dt,h->>'account' bank,(h->>'signed_amount')::numeric amount
  FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]')) h
  JOIN day_keys_v255 k ON k.k=(h->>'event_date')||'|'||(h->>'account')
  WHERE h->>'source'<>'economic_withholding'
 ), daily_v255 AS (
  SELECT r.dt,r.bank,coalesce(sum(r.amount) FILTER(WHERE r.amount>0),0) income,
   coalesce(-sum(r.amount) FILTER(WHERE r.amount<0),0) expense
  FROM rows_v255 r GROUP BY r.dt,r.bank
 )
 SELECT coalesce(jsonb_object_agg(a.dt||'|'||a.bank,jsonb_build_object('income',a.income,'expense',a.expense)),'{}')
 INTO event_daily_v255 FROM daily_v255 a;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP$new1$);
 needle:=$old2$   IF (d->>'date')::date<=date '2026-08-23' THEN
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(cash)h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date';
   ELSE
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]'))h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date' AND h->>'source'<>'economic_withholding';
   END IF;$old2$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_2_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new2$   IF (d->>'date')::date<=date '2026-08-23' THEN
    inc:=coalesce((cash_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'income'])::numeric,0);
    outflow:=coalesce((cash_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'expense'])::numeric,0);
   ELSE
    inc:=coalesce((event_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'income'])::numeric,0);
    outflow:=coalesce((event_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'expense'])::numeric,0);
   END IF;$new2$);
 EXECUTE s;
END $v255$;

DO $verify$
DECLARE u uuid:=public.lts_browser_assert_user_v1();r record;v jsonb;v2 jsonb;t timestamptz;ms numeric;receipt jsonb:='[]';
BEGIN
 FOR r IN SELECT * FROM proof_v255 ORDER BY kind LOOP
 t:=clock_timestamp();v:=public.lts_flow_documentary_bank_sum_v237(u,r.input);ms:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 v2:=public.lts_flow_documentary_bank_sum_v237(u,r.input);
 IF v IS DISTINCT FROM r.prior OR v::text IS DISTINCT FROM r.prior::text OR v2::text IS DISTINCT FROM v::text THEN RAISE EXCEPTION 'V255_FULL_RESPONSE_CHANGED_%',r.kind;END IF;
 receipt:=receipt||jsonb_build_array(jsonb_build_object('range',r.kind,'prior_ms',r.prior_ms,'candidate_ms',ms,'json_and_text_exact',true,'repeat_exact',true,'digest',md5(v::text)));
 END LOOP;
 IF (SELECT proacl::text FROM pg_proc WHERE oid='public.lts_flow_documentary_bank_sum_v237(uuid,jsonb)'::regprocedure) IS DISTINCT FROM (SELECT acl FROM acl_v255) THEN RAISE EXCEPTION 'V255_ACL_CHANGED';END IF;
 PERFORM set_config('lts.v255_receipt',jsonb_build_object('status','PASS','ranges',receipt,'acl_preserved',true,'financial_sources_changed',false,'arithmetic_and_sources_unchanged',true)::text,true);
END $verify$;
SET LOCAL transaction_read_only=on;
DO $readonly$
DECLARE u uuid:=public.lts_browser_assert_user_v1();r record;v jsonb;
BEGIN
 FOR r IN SELECT * FROM proof_v255 LOOP
 v:=public.lts_flow_documentary_bank_sum_v237(u,r.input);
 IF v::text IS DISTINCT FROM r.prior::text THEN RAISE EXCEPTION 'V255_READONLY_RESPONSE_CHANGED';END IF;
 END LOOP;
 PERFORM set_config('lts.v255_readonly','true',true);
END $readonly$;
SELECT current_setting('lts.v255_receipt')::jsonb||jsonb_build_object('readonly_parity',current_setting('lts.v255_readonly')::boolean,'new_helpers',0) AS receipt;
ROLLBACK;