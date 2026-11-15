DO $test$
DECLARE input jsonb;result jsonb;changed jsonb;x jsonb;events jsonb;
BEGIN
 SELECT jsonb_build_object('complete',true,'currency','BRL',
  'account_reminder_cofrinho_v387',jsonb_build_object('value_brl',0,'available_now',true,'as_of',current_date),
  'flow',jsonb_build_object('current_future',jsonb_build_object('events','[]'::jsonb,'days',
   jsonb_agg(jsonb_build_object('date',current_date+i,'Itaú',jsonb_build_object('balance',1000),
    'Bradesco',jsonb_build_object('balance',CASE WHEN i<2 THEN 10 WHEN i<4 THEN -20 ELSE -70 END),
    'C6',jsonb_build_object('balance',0),'fix86_columns',jsonb_build_object('liq_d0_1_recurso',0))ORDER BY i))))
 INTO input FROM generate_series(0,6)i;
 result:=lts_account_reminder_private_v387.evaluate(input,'[]',current_date,7);
 IF result->>'complete'<>'true' OR result->>'plan_complete'<>'true'
  OR jsonb_array_length(result->'actions')<>2
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'actions')a WHERE a->>'to_bank'='Bradesco' AND (a->>'amount_brl')::numeric=20 AND (a->>'execute_by')::date=current_date+1 AND (a->>'risk_date')::date=current_date+2)
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'actions')a WHERE a->>'to_bank'='Bradesco' AND (a->>'amount_brl')::numeric=50 AND (a->>'execute_by')::date=current_date+3 AND (a->>'risk_date')::date=current_date+4)
 THEN RAISE EXCEPTION 'Future trough was anticipated instead of dated incremental needs';END IF;
 IF (result#>>'{accounts,1,first_negative_balance}')::numeric<>-20 OR (result#>>'{accounts,1,worst_balance}')::numeric<>-70
  OR (result#>>'{accounts,1,worst_date}')::date<>current_date+4 THEN RAISE EXCEPTION 'Original risk metrics changed';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(result->'proposed_daily_balances')d WHERE (d->>'Itaú')::numeric<0 OR (d->>'Bradesco')::numeric<0 OR (d->>'C6')::numeric<0)
 THEN RAISE EXCEPTION 'Complete plan leaves an overdraft';END IF;
 FOR x IN SELECT d FROM jsonb_array_elements(result->'proposed_daily_balances')d LOOP
  IF (x->>'Itaú')::numeric+(x->>'Bradesco')::numeric+(x->>'C6')::numeric IS DISTINCT FROM
   (SELECT(d#>>'{Itaú,balance}')::numeric+(d#>>'{Bradesco,balance}')::numeric+(d#>>'{C6,balance}')::numeric FROM jsonb_array_elements(input#>'{flow,current_future,days}')d WHERE d->>'date'=x->>'date')
  THEN RAISE EXCEPTION 'Suggested transfers create resources';END IF;
 END LOOP;
 SELECT jsonb_set(input,'{flow,current_future,days}',jsonb_agg(jsonb_set(d,'{Itaú,balance}','0'))) INTO changed FROM jsonb_array_elements(input#>'{flow,current_future,days}')d;
 result:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 IF result->>'plan_complete'<>'false' OR jsonb_array_length(result->'actions')<>0 OR jsonb_array_length(result->'unfunded')<>2
  OR (SELECT sum((a->>'amount_brl')::numeric) FROM jsonb_array_elements(result->'unfunded')a)<>70
 THEN RAISE EXCEPTION 'Unfunded amount repeated on unchanged negative days';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'proposed_daily_balances')d WHERE (d->>'Bradesco')::numeric<0)
 THEN RAISE EXCEPTION 'Unfunded need became invented bank cash';END IF;
 changed:=jsonb_set(changed,'{account_reminder_cofrinho_v387,value_brl}','40');
 SELECT jsonb_set(changed,'{flow,current_future,days}',jsonb_agg(jsonb_set(d,'{fix86_columns,liq_d0_1_recurso}','40'))) INTO changed FROM jsonb_array_elements(changed#>'{flow,current_future,days}')d;
 result:=lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7);
 IF (result#>>'{cofrinho,suggested_redemptions_brl}')::numeric<>40
  OR (SELECT sum((a->>'amount_brl')::numeric) FROM jsonb_array_elements(result->'unfunded')a)<>30 THEN RAISE EXCEPTION 'Redemption budget reused';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days,0,Itaú,balance}','null');
 IF lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'<>'unknown_account_balance' THEN RAISE EXCEPTION 'Unknown balance converted to zero';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')-2);
 IF lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'<>'missing_or_duplicate_days' THEN RAISE EXCEPTION 'Missing date accepted';END IF;
 changed:=jsonb_set(input,'{flow,current_future,days}',(input#>'{flow,current_future,days}')||jsonb_build_array(input#>'{flow,current_future,days,0}'));
 IF lts_account_reminder_private_v387.evaluate(changed,'[]',current_date,7)->>'reason'<>'missing_or_duplicate_days' THEN RAISE EXCEPTION 'Duplicate date accepted';END IF;
 result:=lts_account_reminder_private_v387.evaluate(input,'[]',current_date,7);
 IF position('Cada linha mostra a necessidade adicional naquela data' IN lts_account_reminder_private_v387.render_email(result||jsonb_build_object('consulted_at',now()),'test')#>>'{html}')=0
 THEN RAISE EXCEPTION 'Email does not explain dated additional needs';END IF;
END $test$;
