"""Execute the real alert migration against synthetic PostgreSQL 17 sources."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
print(r'''
BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001','owner@example.invalid'),('00000000-0000-4000-8000-000000000002','other@example.invalid');
GRANT USAGE ON SCHEMA auth TO service_role;
GRANT SELECT ON auth.users TO service_role;
CREATE TABLE public.financial_events(id integer,amount numeric);
INSERT INTO public.financial_events VALUES(1,500),(2,-100);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text);
CREATE FUNCTION public.lts_open_finance_pilot_owner_v1()RETURNS uuid LANGUAGE sql AS $$SELECT '00000000-0000-4000-8000-000000000001'::uuid$$;
CREATE FUNCTION public.lts_flow_bank_freshness_key_v246(uuid)RETURNS text LANGUAGE sql AS $$SELECT 'synthetic'::text$$;
CREATE FUNCTION public.lts_warm_flow_cache_v245()RETURNS jsonb LANGUAGE sql AS $$SELECT '{"ok":true}'::jsonb$$;
CREATE FUNCTION public.lts_flow_slice_v242(jsonb,date,date)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.lts_flow_card_completeness_v269(jsonb,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_flow_classifications_v290(uuid,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $2$$;
CREATE FUNCTION public.lts_open_finance_current_bank_position_v1(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT '{"bank_cash":500}'::jsonb$$;
CREATE TEMP TABLE source_payload AS SELECT jsonb_build_object('ok',true,'flow',jsonb_build_object('current_future',jsonb_build_object('days',
 (SELECT jsonb_agg(jsonb_build_object('date',current_date+i,'fix86_columns',jsonb_build_object(
 'saldo_apos_d0_1',CASE WHEN i=20 THEN -20 ELSE 500 END,
 'saldo_apos_rsu',500,'saldo_apos_fgts',500))ORDER BY i)FROM generate_series(0,179)i))))j;
INSERT INTO public.lts_v229_read_cache SELECT public.lts_open_finance_pilot_owner_v1(),'flow_v242',current_date,current_date,current_date+179,j,clock_timestamp(),'v246.1:1:synthetic'FROM source_payload;
INSERT INTO public.lts_v229_read_cache SELECT '00000000-0000-4000-8000-000000000002','flow_v242',current_date,current_date,current_date+179,'{"other_owner":true}',clock_timestamp(),'v246.1:1:synthetic';
GRANT SELECT ON public.lts_v229_read_cache,public.lts_read_cache_epoch_v242 TO service_role;
''')
print((ROOT/'backend/patches/v377/cash_alerts.sql').read_text())
print(r'''
DO $test$
DECLARE input jsonb:=(SELECT j FROM source_payload);result jsonb;x jsonb;changed jsonb;prev jsonb;snapshot jsonb;log_result jsonb;
 original text:=(SELECT md5(jsonb_agg(to_jsonb(f)ORDER BY id)::text)FROM public.financial_events f);
BEGIN
 result:=lts_cash_alert_private_v377.evaluate(input,current_date);
 IF jsonb_array_length(result->'windows')<>12 OR result->>'complete'<>'true'OR result->>'status'<>'risk'THEN RAISE EXCEPTION 'Complete twelve-scenario summary failed';END IF;
 SELECT value INTO x FROM jsonb_array_elements(result->'windows')WHERE value->>'scenario'='cash'AND value->>'days'='7';
 IF x->>'first_negative_date'IS NOT NULL OR(x->>'known_days')::integer<>7 OR(x->>'worst_balance')::numeric<>500 THEN RAISE EXCEPTION 'Seven-day boundary failed';END IF;
 SELECT value INTO x FROM jsonb_array_elements(result->'windows')WHERE value->>'scenario'='cash'AND value->>'days'='30';
 IF(x->>'first_negative_date')::date<>current_date+20 OR(x->>'worst_balance')::numeric<>-20 OR(x->>'negative_days')::integer<>1 THEN RAISE EXCEPTION 'Negative first day/value failed';END IF;
 SELECT value INTO x FROM jsonb_array_elements(result->'windows')WHERE value->>'scenario'='fgts'AND value->>'days'='180';
 IF x->>'first_negative_date'IS NOT NULL THEN RAISE EXCEPTION 'Scenarios mixed';END IF;
 IF lts_cash_alert_private_v377.decision(result,NULL,NULL,now())->>'send'<>'true'THEN RAISE EXCEPTION 'First risk suppressed';END IF;
 IF lts_cash_alert_private_v377.decision(result,result,now()-interval'1 day',now())->>'send'<>'false'THEN RAISE EXCEPTION 'Unchanged risk repeated';END IF;
 IF lts_cash_alert_private_v377.decision(result,result,now()-interval'7 days',now())->>'reason'<>'weekly_risk_reminder'THEN RAISE EXCEPTION 'Persistent reminder failed';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,20,fix86_columns,saldo_apos_d0_1}','-120');
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF lts_cash_alert_private_v377.decision(changed,result,now(),now())->>'send'<>'true'THEN RAISE EXCEPTION 'Deeper risk suppressed';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,5,fix86_columns,saldo_apos_d0_1}','-1');
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF lts_cash_alert_private_v377.decision(changed,result,now(),now())->>'send'<>'true'THEN RAISE EXCEPTION 'Earlier/shorter-window risk suppressed';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,20,fix86_columns,saldo_apos_d0_1}','500');
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF changed->>'status'<>'clear'OR lts_cash_alert_private_v377.decision(changed,result,now(),now())->>'reason'<>'risk_cleared'THEN RAISE EXCEPTION 'Recovery failed';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,2,fix86_columns,saldo_apos_rsu}','null');
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 SELECT value INTO x FROM jsonb_array_elements(changed->'windows')WHERE value->>'scenario'='shares'AND value->>'days'='7';
 IF x->>'complete'<>'false'OR x->>'missing_days'<>'1'THEN RAISE EXCEPTION 'Null converted to zero';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')-2);
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF changed->>'complete'<>'false'THEN RAISE EXCEPTION 'Missing calendar day accepted';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')||jsonb_build_array(input#>'{flow,current_future,days,0}'));
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF changed->>'complete'<>'false'THEN RAISE EXCEPTION 'Duplicate day accepted';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,0,date}','"bad-date"');
 changed:=lts_cash_alert_private_v377.evaluate(changed,current_date);
 IF changed->>'complete'<>'false'OR changed->>'invalid_date_rows'<>'1'THEN RAISE EXCEPTION 'Invalid date accepted';END IF;
 changed:=lts_cash_alert_private_v377.evaluate('{"complete":false,"flow":{"current_future":{"days":[]}}}',current_date);
 IF changed->>'status'<>'unknown'OR lts_cash_alert_private_v377.decision(changed,result,now(),now())->>'send'<>'false'THEN RAISE EXCEPTION 'Unknown converted to recovery';END IF;
 IF lts_cash_alert_private_v377.evaluate('{}',current_date)->>'status'<>'unavailable'THEN RAISE EXCEPTION 'Unavailable input accepted';END IF;
 snapshot:=public.lts_cash_alert_snapshot_v377();
 IF snapshot#>>'{report,recipient}'<>'owner@example.invalid'OR snapshot#>>'{report,status}'<>'risk'THEN RAISE EXCEPTION 'Wrong owner snapshot';END IF;
 changed:=jsonb_set(snapshot,'{report,recipient}','"other@example.invalid"');
 changed:=jsonb_set(changed,'{delivery_token}',to_jsonb(lts_cash_alert_private_v377.fingerprint(changed->'report')));
 BEGIN PERFORM public.lts_cash_alert_record_sent_v377(changed,'synthetic-message');RAISE EXCEPTION 'Wrong recipient accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='Wrong recipient accepted'THEN RAISE;END IF;END;
 log_result:=public.lts_cash_alert_record_sent_v377(snapshot,'synthetic-message');
 IF log_result->>'recorded'<>'true'THEN RAISE EXCEPTION 'Confirmed delivery not logged';END IF;
 IF public.lts_cash_alert_record_sent_v377(snapshot,'synthetic-message')->>'already_recorded'<>'true'THEN RAISE EXCEPTION 'Delivery retry duplicated';END IF;
 IF(SELECT count(*)FROM lts_cash_alert_private_v377.delivery)<>1 THEN RAISE EXCEPTION 'Duplicate delivery rows';END IF;
 BEGIN PERFORM public.lts_cash_alert_record_sent_v377(snapshot,'different-message');RAISE EXCEPTION 'Conflicting retry accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='Conflicting retry accepted'THEN RAISE;END IF;END;
 IF public.lts_cash_alert_snapshot_v377()#>>'{decision,send}'<>'false'THEN RAISE EXCEPTION 'Sent risk repeated';END IF;
 BEGIN UPDATE public.lts_v229_read_cache SET source_fingerprint='stale'WHERE user_id=public.lts_open_finance_pilot_owner_v1();
 PERFORM public.lts_cash_alert_snapshot_v377();RAISE EXCEPTION 'Stale forecast accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='Stale forecast accepted'THEN RAISE;END IF;END;
 IF original IS DISTINCT FROM(SELECT md5(jsonb_agg(to_jsonb(f)ORDER BY id)::text)FROM public.financial_events f)THEN RAISE EXCEPTION 'Financial source changed';END IF;
 IF has_schema_privilege('authenticated','lts_cash_alert_private_v377','USAGE')
 OR has_function_privilege('authenticated','public.lts_cash_alert_snapshot_v377()','EXECUTE')
 OR has_function_privilege('anon','public.lts_cash_alert_record_sent_v377(jsonb,text)','EXECUTE')
 OR EXISTS(SELECT 1 FROM pg_proc WHERE oid IN('public.lts_cash_alert_snapshot_v377()'::regprocedure,'public.lts_cash_alert_record_sent_v377(jsonb,text)'::regprocedure)AND prosecdef)
 THEN RAISE EXCEPTION 'Alert endpoint exposed';END IF;
END $test$;
SELECT jsonb_build_object('version',377,'pass',true,'twelve_metrics',true,'calendar_coverage',true,'missing_null_duplicate_invalid_rejected',true,
 'isolated_scenarios',true,'unchanged_suppressed',true,'earlier_deeper_and_weekly',true,'recovery_not_unknown',true,'owner_only',true,
 'confirmed_delivery_idempotence',true,'wrong_recipient_and_conflicting_retry_rejected',true,'stale_cache_rejected',true,'financial_rows_unchanged',true,'private_acl',true,'synthetic_native',true);
ROLLBACK;
''')
