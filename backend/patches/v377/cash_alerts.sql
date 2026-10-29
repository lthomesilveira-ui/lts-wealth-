-- Forecast notifications are separate from financial source records.
CREATE SCHEMA lts_cash_alert_private_v377;
REVOKE ALL ON SCHEMA lts_cash_alert_private_v377 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_cash_alert_private_v377 TO service_role;
CREATE TABLE lts_cash_alert_private_v377.delivery (
 token text PRIMARY KEY CHECK(token~'^[0-9a-f]{32}$'),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 message_id text NOT NULL UNIQUE CHECK(length(message_id) BETWEEN 1 AND 200),
 sent_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 report jsonb NOT NULL CHECK(jsonb_typeof(report)='object')
);
ALTER TABLE lts_cash_alert_private_v377.delivery ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON lts_cash_alert_private_v377.delivery FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT,INSERT ON lts_cash_alert_private_v377.delivery TO service_role;
CREATE POLICY service_delivery ON lts_cash_alert_private_v377.delivery TO service_role
 USING(true) WITH CHECK(true);
CREATE INDEX delivery_user_sent_v377 ON lts_cash_alert_private_v377.delivery(user_id,sent_at DESC);

-- The service role cannot read auth.users directly. This private, zero-argument
-- helper returns only the configured owner's address and exposes no user list.
CREATE FUNCTION lts_cash_alert_private_v377.owner_email()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT email FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1();
$fn$;

CREATE FUNCTION lts_cash_alert_private_v377.evaluate(p_payload jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $fn$
DECLARE metrics jsonb;bad_dates integer;result jsonb;
BEGIN
 IF p_as_of IS NULL OR jsonb_typeof(p_payload#>'{flow,current_future,days}')IS DISTINCT FROM'array'
 THEN RETURN jsonb_build_object('version',377,'as_of',p_as_of,'status','unavailable','windows','[]'::jsonb,'complete',false);END IF;
 SELECT count(*) INTO bad_dates
 FROM jsonb_array_elements(p_payload#>'{flow,current_future,days}') x
 WHERE NOT coalesce(pg_input_is_valid(x->>'date','date'),false);
 WITH raw_days AS MATERIALIZED (
  SELECT CASE WHEN pg_input_is_valid(x->>'date','date')THEN(x->>'date')::date END AS event_date,x
  FROM jsonb_array_elements(p_payload#>'{flow,current_future,days}')x
 ), unique_days AS MATERIALIZED (
  SELECT event_date,min(x::text)::jsonb AS x,count(*) AS copies
  FROM raw_days WHERE event_date BETWEEN p_as_of AND p_as_of+179 GROUP BY event_date
 ), scenarios(id,field,label)AS(VALUES
  ('cash','saldo_apos_d0_1','Conta e aplicações D0/D1'),
  ('shares','saldo_apos_rsu','Com ações'),
  ('fgts','saldo_apos_fgts','Com ações e FGTS')),
 horizons(days)AS(VALUES(7),(30),(90),(180)),
 points AS MATERIALIZED (
  SELECT h.days,s.id,s.label,g.d::date AS event_date,u.copies,
   CASE WHEN u.copies=1 AND jsonb_typeof(u.x#>ARRAY['fix86_columns',s.field])='number'
   THEN(u.x#>>ARRAY['fix86_columns',s.field])::numeric END AS balance
  FROM horizons h CROSS JOIN scenarios s
  CROSS JOIN LATERAL generate_series(p_as_of,p_as_of+h.days-1,interval'1 day')g(d)
  LEFT JOIN unique_days u ON u.event_date=g.d::date
 ), aggregated AS (
  SELECT days,id,label,count(balance) AS known_days,
   count(*)FILTER(WHERE copies>1) AS duplicate_days,
   min(balance) AS worst_balance,
   (array_agg(event_date ORDER BY balance,event_date)FILTER(WHERE balance IS NOT NULL))[1] AS worst_date,
   min(event_date)FILTER(WHERE balance<0) AS first_negative_date,
   count(*)FILTER(WHERE balance<0) AS negative_days
  FROM points GROUP BY days,id,label
 )
 SELECT jsonb_agg(jsonb_build_object(
  'days',a.days,'from',p_as_of,'to',p_as_of+a.days-1,'scenario',a.id,'label',a.label,
  'known_days',a.known_days,'missing_days',a.days-a.known_days,'duplicate_days',a.duplicate_days,
  'complete',a.known_days=a.days AND bad_dates=0 AND coalesce(p_payload->>'complete','true')<>'false',
  'first_negative_date',a.first_negative_date,
  'first_negative_balance',(SELECT p.balance::text FROM points p WHERE p.days=a.days AND p.id=a.id AND p.event_date=a.first_negative_date),
  'worst_balance',a.worst_balance::text,'worst_date',a.worst_date,'negative_days',a.negative_days
 )ORDER BY a.days,a.id) INTO metrics FROM aggregated a;
 result:=jsonb_build_object('version',377,'as_of',p_as_of,'includes_today',true,
  'status',CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(metrics)x WHERE x->>'first_negative_date'IS NOT NULL)THEN'risk'
   WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(metrics)x WHERE x->>'complete'<>'true')THEN'unknown'ELSE'clear'END,
  'complete',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(metrics)x WHERE x->>'complete'<>'true'),
  'invalid_date_rows',bad_dates,'windows',metrics);
 RETURN result;
END $fn$;

CREATE FUNCTION lts_cash_alert_private_v377.decision(p_current jsonb,p_previous jsonb,p_last_sent timestamptz,p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE c jsonb;p jsonb;reason text;
BEGIN
 IF p_current->>'status'='risk' THEN
  IF p_previous IS NULL OR p_previous->>'status'<>'risk' THEN reason:='new_risk';
  ELSE
   FOR c IN SELECT value FROM jsonb_array_elements(p_current->'windows')WHERE value->>'first_negative_date'IS NOT NULL LOOP
    SELECT value INTO p FROM jsonb_array_elements(p_previous->'windows')
    WHERE value->>'scenario'=c->>'scenario'AND value->>'days'=c->>'days';
    IF p IS NULL OR p->>'first_negative_date'IS NULL THEN reason:='new_scenario_or_shorter_window';EXIT;
    ELSIF(c->>'first_negative_date')::date<(p->>'first_negative_date')::date THEN reason:='earlier_negative_date';EXIT;
    ELSIF(c->>'worst_balance')::numeric<=(p->>'worst_balance')::numeric-100 THEN reason:='deficit_increased_at_least_100';EXIT;END IF;
   END LOOP;
   IF reason IS NULL AND (p_last_sent IS NULL OR p_now-p_last_sent>=interval'7 days')THEN reason:='weekly_risk_reminder';END IF;
  END IF;
 ELSIF p_current->>'status'='clear'AND p_current->>'complete'='true'AND p_previous->>'status'='risk' THEN reason:='risk_cleared';
 END IF;
 RETURN jsonb_build_object('send',reason IS NOT NULL,'reason',coalesce(reason,'no_material_change'));
END $fn$;

-- Identity uses only text, booleans and integer fields. Resource amounts in
-- bank metadata may cross a JSON client boundary with different numeric scale.
CREATE FUNCTION lts_cash_alert_private_v377.fingerprint(p_report jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT md5(jsonb_build_object('version',p_report->'version','as_of',p_report->>'as_of',
  'recipient',lower(p_report->>'recipient'),'status',p_report->>'status',
  'complete',p_report->'complete','windows',p_report->'windows')::text);
$fn$;

CREATE FUNCTION public.lts_cash_alert_snapshot_v377()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='60s' AS $fn$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();mail text;cached jsonb;j jsonb;report jsonb;
 previous jsonb;last_sent timestamptz;epoch_before bigint;freshness text;now_at timestamptz:=clock_timestamp();
BEGIN
 mail:=lts_cash_alert_private_v377.owner_email();
 IF mail IS NULL THEN RAISE EXCEPTION 'Configured alert recipient unavailable';END IF;
 -- Reuse the existing, owner-scoped warming worker and the exact V242 cache.
 -- This does not create a browser session or alter financial sources.
 PERFORM public.lts_warm_flow_cache_v245();
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 freshness:=public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO cached FROM public.lts_v229_read_cache
 WHERE user_id=u AND kind='flow_v242'AND as_of=current_date
 AND from_date<=current_date AND to_date>=current_date+179
 AND source_fingerprint='v246.1:'||epoch_before||':'||freshness
 AND refreshed_at>clock_timestamp()-interval'30 minutes'
 ORDER BY refreshed_at DESC LIMIT 1;
 IF cached IS NULL THEN RAISE EXCEPTION 'Fresh owner forecast unavailable';END IF;
 j:=public.lts_flow_classifications_v290(u,public.lts_flow_card_completeness_v269(
  public.lts_flow_slice_v242(cached,current_date,current_date+179),public.lts_prepared_card_cycles_v307(u)));
 IF epoch_before<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)
 OR freshness<>public.lts_flow_bank_freshness_key_v246(u)
 THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Forecast sources changed during alert read';END IF;
 report:=lts_cash_alert_private_v377.evaluate(j,current_date)||jsonb_build_object(
  'recipient',mail,'consulted_at',now_at,'reader','same_dashboard_v242',
  'bank_sources',public.lts_open_finance_current_bank_position_v1(u),
  'incomplete_families',j->'incomplete_families',
  'fgts_contract',j#>'{flow,fgts_projection_contract}',
  'assumption','Forecast only. Shares and FGTS follow the existing availability assumptions; they are not current bank cash.');
 SELECT d.report,d.sent_at INTO previous,last_sent FROM lts_cash_alert_private_v377.delivery d WHERE user_id=u ORDER BY sent_at DESC LIMIT 1;
 RETURN jsonb_build_object('report',report,'delivery_token',lts_cash_alert_private_v377.fingerprint(report),
  'decision',lts_cash_alert_private_v377.decision(report,previous,last_sent,now_at),
  'previous_sent_at',last_sent);
END $fn$;

CREATE FUNCTION public.lts_cash_alert_record_sent_v377(p_snapshot jsonb,p_message_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $fn$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();mail text;v_token text;previous_id text;
BEGIN
 mail:=lts_cash_alert_private_v377.owner_email();
 IF mail IS NULL THEN RAISE EXCEPTION 'Configured alert recipient unavailable';END IF;
 v_token:=p_snapshot->>'delivery_token';
 IF v_token IS NULL OR v_token IS DISTINCT FROM lts_cash_alert_private_v377.fingerprint(p_snapshot->'report')
 OR lower(p_snapshot#>>'{report,recipient}')IS DISTINCT FROM lower(mail)
 OR p_snapshot#>>'{decision,send}'IS DISTINCT FROM'true'
 OR p_message_id IS NULL OR length(p_message_id)NOT BETWEEN 1 AND 200 OR p_message_id~'[[:cntrl:]]'
 THEN RAISE EXCEPTION 'Invalid confirmed alert delivery';END IF;
 SELECT message_id INTO previous_id FROM lts_cash_alert_private_v377.delivery WHERE delivery.token=v_token;
 IF FOUND THEN
  IF previous_id IS DISTINCT FROM p_message_id THEN RAISE EXCEPTION 'Alert token already recorded for a different message';END IF;
  RETURN jsonb_build_object('recorded',true,'already_recorded',true);
 END IF;
 INSERT INTO lts_cash_alert_private_v377.delivery(token,user_id,message_id,report)
 VALUES(v_token,u,p_message_id,p_snapshot->'report');
 RETURN jsonb_build_object('recorded',true,'already_recorded',false);
END $fn$;
REVOKE ALL ON FUNCTION lts_cash_alert_private_v377.evaluate(jsonb,date),
 lts_cash_alert_private_v377.owner_email(),
 lts_cash_alert_private_v377.fingerprint(jsonb),
 lts_cash_alert_private_v377.decision(jsonb,jsonb,timestamptz,timestamptz),
 public.lts_cash_alert_snapshot_v377(),public.lts_cash_alert_record_sent_v377(jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_cash_alert_private_v377.evaluate(jsonb,date),
 lts_cash_alert_private_v377.owner_email(),
 lts_cash_alert_private_v377.fingerprint(jsonb),
 lts_cash_alert_private_v377.decision(jsonb,jsonb,timestamptz,timestamptz),
 public.lts_cash_alert_snapshot_v377(),public.lts_cash_alert_record_sent_v377(jsonb,text) TO service_role;
