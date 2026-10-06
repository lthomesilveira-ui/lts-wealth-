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
