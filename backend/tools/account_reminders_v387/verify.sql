\set ON_ERROR_STOP on
SET TIME ZONE 'America/Sao_Paulo';
DO $test$
DECLARE input jsonb:=public.fixture_payload_v387(current_date,7);r jsonb;changed jsonb;s jsonb;previous jsonb;result jsonb;events jsonb;
 fingerprint text;snapshot jsonb;rows_before text:=(SELECT md5(jsonb_agg(to_jsonb(f)ORDER BY id)::text)FROM public.fixture_financial_events f);
BEGIN
 r:=lts_account_reminder_private_v387.evaluate(input,'[]',current_date,7);
 PERFORM public.fixture_assert_v387(r->>'complete'='true'AND r->>'plan_complete'='true','complete calendar with safe full plan');
 PERFORM public.fixture_assert_v387(jsonb_array_length(r->'actions')=3 AND(r#>>'{cofrinho,suggested_redemptions_brl}')::numeric=90 AND(r#>>'{cofrinho,remaining_planning_budget_brl}')::numeric=10,'Cofrinho used once and relay merged');
 PERFORM public.fixture_assert_v387(EXISTS(SELECT 1 FROM jsonb_array_elements(r->'actions')x WHERE x->>'kind'='suggested_redemption'AND(x->>'amount_brl')::numeric=70 AND(x->>'execute_by')::date=current_date+1),'Itaú redemption by day before risk');
 PERFORM public.fixture_assert_v387(EXISTS(SELECT 1 FROM jsonb_array_elements(r->'actions')x WHERE x->>'kind'='suggested_transfer'AND x->>'from_bank'='Itaú'AND x->>'to_bank'='Bradesco'AND(x->>'amount_brl')::numeric=190 AND(x->>'rescue_before_transfer_brl')::numeric=20),'transfer includes conditional redemption first');
 PERFORM public.fixture_assert_v387(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'proposed_daily_balances')x WHERE(x->>'Itaú')::numeric<0 OR(x->>'Bradesco')::numeric<0 OR(x->>'C6')::numeric<0),'all accounts remain nonnegative throughout horizon');
 PERFORM public.fixture_assert_v387(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'proposed_daily_balances')x WHERE
 (x->>'Itaú')::numeric+(x->>'Bradesco')::numeric+(x->>'C6')::numeric+(100-coalesce((SELECT sum((a->>'amount_brl')::numeric)FROM jsonb_array_elements(r->'actions')a WHERE a->>'kind'='suggested_redemption'AND(a->>'execute_by')::date<=(x->>'date')::date),0))
 IS DISTINCT FROM(SELECT(d#>>'{Itaú,balance}')::numeric+(d#>>'{Bradesco,balance}')::numeric+(d#>>'{C6,balance}')::numeric+100 FROM jsonb_array_elements(input#>'{flow,current_future,days}')d WHERE d->>'date'=x->>'date')),'bank transfers and redemptions conserve combined resources');
 PERFORM public.fixture_assert_v387(r#>>'{accounts,0,first_negative_date}'=(current_date+2)::text AND(r#>>'{accounts,0,first_negative_balance}')::numeric=-20 AND(r#>>'{accounts,0,worst_balance}')::numeric=-70,'per bank first negative and worst values from actual days');
 changed:=jsonb_set(input,'{account_reminder_cofrinho_v387,value_brl}','20');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387((s#>>'{cofrinho,suggested_redemptions_brl}')::numeric<=20 AND s->>'plan_complete'='false','other D0 assets cannot be offered as Cofrinho');
 s:=lts_account_reminder_private_v387.evaluate(input-'account_reminder_cofrinho_v387','[]',current_date,7);
 PERFORM public.fixture_assert_v387(s#>>'{cofrinho,reference_balance_brl}'IS NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(s->'actions')x WHERE x->>'kind'='suggested_redemption'),'missing documented Cofrinho does not inherit aggregate D0');
 changed:=jsonb_set(input,'{account_reminder_cofrinho_v387,available_now}','false');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387(s#>>'{cofrinho,planning_budget_brl}'IS NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(s->'actions')x WHERE x->>'kind'='suggested_redemption'),'unavailable Cofrinho cannot fund a redemption');
 -- Explicit zero is valid; absent numbers are not zero.
 SELECT jsonb_set(input,'{flow,current_future,days}',jsonb_agg(jsonb_set(jsonb_set(jsonb_set(jsonb_set(x,'{Itaú,balance}','0'),'{Bradesco,balance}','0'),'{C6,balance}','0'),'{fix86_columns,liq_d0_1_recurso}','0')))INTO changed FROM jsonb_array_elements(input#>'{flow,current_future,days}')x;
 changed:=jsonb_set(changed,'{account_reminder_cofrinho_v387,value_brl}','0');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387(s->>'status'='clear'AND s->>'complete'='true'AND lts_account_reminder_private_v387.decision(s,NULL,NULL,now())->>'send'='false','explicit zero clear without unnecessary email');
 changed:=jsonb_set(input,'{flow,current_future,days,0,Itaú,balance}','null');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'='unknown_account_balance','null bank unknown');
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')-2);
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'='missing_or_duplicate_days','missing calendar rejected');
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')||jsonb_build_array(input#>'{flow,current_future,days,0}'));
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'='missing_or_duplicate_days','duplicate day rejected');
 changed:=jsonb_set(input,'{flow,current_future,days,0,date}','"bad-date"');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'='invalid_dates','invalid date rejected');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(jsonb_set(input,'{complete}','false'),'[]',current_date,7)->>'status'='unknown','incomplete root not accepted');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(jsonb_set(input,'{currency}','"USD"'),'[]',current_date,7)->>'status'='unknown','wrong currency rejected');
 changed:=jsonb_set(input,'{flow,current_future,days,0,fix86_columns,liq_d0_1_recurso}','null');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387(s->>'plan_complete'='false'AND s#>>'{cofrinho,planning_budget_brl}'IS NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(s->'actions')x WHERE x->>'kind'='suggested_redemption'),'unknown Cofrinho never offered or labeled zero');
 changed:=jsonb_set(input,'{flow,current_future,days,6,fix86_columns,liq_d0_1_recurso}','5');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387((s#>>'{cofrinho,suggested_redemptions_brl}')::numeric<=5 AND s->>'plan_complete'='false'AND jsonb_array_length(s->'unfunded')>0,'future resource reduction reserved and shortage explicit');
 changed:=jsonb_set(input,'{flow,current_future,days,6,Itaú,balance}','-1000');s:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 PERFORM public.fixture_assert_v387(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(s->'actions')x WHERE x->>'kind'='suggested_transfer'AND x->>'from_bank'='Itaú'AND coalesce((x->>'rescue_before_transfer_brl')::numeric,0)=0),'future source overdraft cannot fund another bank');
 events:=jsonb_build_array(jsonb_build_object('source','internal_transfer','is_projection',true,'event_date',current_date+2,'source_ref','bank_schedule:00000000-0000-4000-8000-000000000004:out','account','Itaú','signed_amount',-25),jsonb_build_object('source','internal_transfer','is_projection',true,'event_date',current_date+2,'source_ref','bank_schedule:00000000-0000-4000-8000-000000000004:in','account','C6','signed_amount',25));
 changed:=jsonb_set(input,'{flow,current_future,events}',events);
 s:=jsonb_build_array(jsonb_build_object('source_id','00000000-0000-4000-8000-000000000004','scheduled_date',current_date+2,'from_bank','Itaú','to_bank','C6','amount_brl','25'));
 result:=lts_account_reminder_private_v387.evaluate(changed,s,current_date,7);
 PERFORM public.fixture_assert_v387(result#>>'{scheduled_transfers,0,already_scheduled}'='true'AND result#>>'{scheduled_transfers,0,represented_in_forecast}'='true'AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'actions')x WHERE x->>'to_bank'='C6'),'existing schedule checked rather than repeated');
 changed:=jsonb_set(changed,'{flow,current_future,events,1,source_ref}','"bank_schedule:00000000-0000-4000-8000-000000000005:in"');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,s,current_date,7)->>'reason'='scheduled_transfer_requires_reconciliation','equal amount/date does not pair unrelated identities');
 changed:=jsonb_set(input,'{flow,current_future,events}',jsonb_build_array(events->0,events->0));
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.evaluate(changed,s,current_date,7)->>'reason'='scheduled_transfer_requires_reconciliation','duplicate out leg does not stand in for incoming leg');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.decision(r,NULL,NULL,now())->>'send'='true','first actionable plan delivered');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.decision(r,r,now(),now())->>'send'='false','same day unchanged plan suppressed');
 previous:=jsonb_set(r,'{as_of}',to_jsonb((current_date-1)::text));
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.decision(r,previous,now()-interval'1 day',now())->>'reason'='daily_action_reminder','daily reminder when action due in seven days');
 s:=jsonb_set(r,'{actions}',jsonb_build_array(jsonb_set(r#>'{actions,0}','{execute_by}',to_jsonb((current_date+15)::text))));s:=jsonb_set(s,'{accounts}','[]');s:=jsonb_set(s,'{scheduled_transfers}','[]');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.decision(s,s,now()-interval'1 day',now())->>'send'='false'AND lts_account_reminder_private_v387.decision(s,s,now()-interval'7 days',now())->>'reason'='weekly_plan_review','distant unchanged plan reviewed weekly');
 changed:=jsonb_set(r,'{actions,0,amount_brl}','"170"');
 PERFORM public.fixture_assert_v387(lts_account_reminder_private_v387.decision(changed,r,now(),now())->>'send'='true','material action change delivered');
 fingerprint:=lts_account_reminder_private_v387.fingerprint(r);
 PERFORM public.fixture_assert_v387(fingerprint<>lts_account_reminder_private_v387.fingerprint(jsonb_set(r,'{cofrinho,planning_budget_brl}','"99"')),'resource budget change has new token');
 snapshot:=public.lts_account_reminder_snapshot_v387();
 PERFORM public.fixture_assert_v387(snapshot#>>'{report,recipient}'='owner@example.invalid'AND snapshot#>>'{report,complete}'='true','snapshot bound to configured owner');
 PERFORM public.fixture_assert_v387(position('Resgatar do Cofrinho'IN snapshot#>>'{email,html}')>0 AND position('Transferir de Itaú para Bradesco'IN snapshot#>>'{email,html}')>0 AND position('R$ 190,00'IN snapshot#>>'{email,html}')>0,'prepared HTML shows concrete actions and BRL amounts');
 changed:=jsonb_set(snapshot,'{report,recipient}','"other@example.invalid"');changed:=jsonb_set(changed,'{delivery_token}',to_jsonb(lts_account_reminder_private_v387.fingerprint(changed->'report')));
 BEGIN PERFORM public.lts_account_reminder_record_sent_v387(changed,'synthetic-id');RAISE EXCEPTION 'Wrong recipient accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Invalid confirmed account reminder delivery'THEN RAISE;END IF;END;
 PERFORM public.fixture_assert_v387(true,'wrong recipient refused');
 changed:=jsonb_set(snapshot,'{email,html}','"altered"');
 BEGIN PERFORM public.lts_account_reminder_record_sent_v387(changed,'synthetic-id');RAISE EXCEPTION 'Altered HTML accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Invalid confirmed account reminder delivery'THEN RAISE;END IF;END;
 PERFORM public.fixture_assert_v387(true,'altered prepared HTML refused');
 BEGIN PERFORM public.lts_account_reminder_record_sent_v387(snapshot,E'bad\nid');RAISE EXCEPTION 'Control ID accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Invalid confirmed account reminder delivery'THEN RAISE;END IF;END;
 PERFORM public.fixture_assert_v387(true,'control characters in message identity refused');
 result:=public.lts_account_reminder_record_sent_v387(snapshot,'synthetic-id');
 PERFORM public.fixture_assert_v387(result->>'recorded'='true'AND public.lts_account_reminder_record_sent_v387(snapshot,'synthetic-id')->>'already_recorded'='true'AND(SELECT count(*)FROM lts_account_reminder_private_v387.delivery)=1,'confirmed delivery idempotent');
 BEGIN PERFORM public.lts_account_reminder_record_sent_v387(snapshot,'conflicting-id');RAISE EXCEPTION 'Conflicting retry accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Reminder token already recorded for a different message'THEN RAISE;END IF;END;
 PERFORM public.fixture_assert_v387(true,'conflicting message retry refused');
 PERFORM public.fixture_assert_v387(public.lts_account_reminder_snapshot_v387()#>>'{decision,send}'='false','recorded plan not sent twice');
 BEGIN UPDATE public.lts_v229_read_cache SET source_fingerprint='stale'WHERE user_id=public.lts_open_finance_pilot_owner_v1();PERFORM public.lts_account_reminder_snapshot_v387();RAISE EXCEPTION 'Stale cache accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Fresh owner forecast unavailable'THEN RAISE;END IF;END;
 PERFORM public.fixture_assert_v387(true,'stale owner cache refused');
 PERFORM public.fixture_assert_v387(rows_before=(SELECT md5(jsonb_agg(to_jsonb(f)ORDER BY id)::text)FROM public.fixture_financial_events f),'financial sources unchanged');
 PERFORM public.fixture_assert_v387(NOT has_schema_privilege('authenticated','lts_account_reminder_private_v387','USAGE')AND NOT has_function_privilege('authenticated','public.lts_account_reminder_snapshot_v387()','EXECUTE')AND NOT has_function_privilege('anon','public.lts_account_reminder_record_sent_v387(jsonb,text)','EXECUTE')AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid IN('public.lts_account_reminder_snapshot_v387()'::regprocedure,'public.lts_account_reminder_record_sent_v387(jsonb,text)'::regprocedure)AND prosecdef),'private invoker only role boundaries');
 PERFORM public.fixture_assert_v387(NOT has_table_privilege('service_role','lts_account_reminder_private_v387.delivery','UPDATE')AND NOT has_table_privilege('service_role','lts_account_reminder_private_v387.delivery','DELETE'),'journal append only service access');
END $test$;
SET ROLE service_role;
DO $service$BEGIN IF public.lts_account_reminder_snapshot_v387()#>>'{report,recipient}'<>'owner@example.invalid'OR has_table_privilege('service_role','auth.users','SELECT')THEN RAISE EXCEPTION 'Service role or narrow recipient helper failed';END IF;END $service$;
RESET ROLE;
SELECT public.fixture_assert_v387(true,'service reads without auth users select');
-- A confirmed schedule passes through the native controller once, with its two
-- exact canonical legs; the other owner's schedule must stay out.
INSERT INTO public.fixture_bank_schedules_v387 VALUES
(public.lts_open_finance_pilot_owner_v1(),'00000000-0000-4000-8000-000000000004',current_date+2,'Itaú','C6',-25),
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000005',current_date+2,'Itaú','C6',-999);
UPDATE public.lts_v229_read_cache SET payload=jsonb_set(payload,'{flow,current_future,events}',jsonb_build_array(
 jsonb_build_object('source','internal_transfer','is_projection',true,'event_date',current_date+2,'source_ref','bank_schedule:00000000-0000-4000-8000-000000000004:out','account','Itaú','signed_amount',-25),
 jsonb_build_object('source','internal_transfer','is_projection',true,'event_date',current_date+2,'source_ref','bank_schedule:00000000-0000-4000-8000-000000000004:in','account','C6','signed_amount',25)))WHERE user_id=public.lts_open_finance_pilot_owner_v1();
SELECT public.fixture_assert_v387(jsonb_array_length(public.lts_account_reminder_snapshot_v387()#>'{report,scheduled_transfers}')=1 AND position('não repetir a transferência'IN public.lts_account_reminder_snapshot_v387()#>>'{email,html}')>0,'owner schedule rendered only as execution check');
-- The preview is synthetic and does not contain any owner's personal data.
\pset tuples_only on
\pset format unaligned
\o /tmp/v387-email-preview.html
SELECT (public.lts_account_reminder_snapshot_v387())#>>'{email,html}';
\o
SELECT jsonb_build_object('version',387,'pass',true,'cases',(SELECT count(*)FROM public.fixture_assertions_v387),'synthetic_native',true,'physical_device_certified',false);
