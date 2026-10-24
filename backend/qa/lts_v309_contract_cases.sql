DO $check$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';s jsonb;j jsonb;c jsonb;w jsonb;
BEGIN
 s:=public.lts_commitment_read_state_v309(u,'2020-10-24');
 IF s#>>'{cipo_396,future_count}'<>'2' OR s#>>'{cipo_396,future_total}'<>'130' OR s#>>'{cipo_396,next_due}'<>'2020-11-20'
 OR s#>>'{cipo_396,confirmed_loaded_paid_count}'<>'2' OR s#>>'{cipo_396,unconfirmed_past_count}'<>'0'
 THEN RAISE EXCEPTION 'CIPO future/paid split wrong: %',s->'cipo_396';END IF;
 IF s#>>'{coopharma,future_count}'<>'2' OR s#>>'{coopharma,unconfirmed_past_count}'<>'1'
 OR s#>>'{coopharma,confirmed_loaded_paid_count}'<>'1' THEN RAISE EXCEPTION 'Payroll past must remain unconfirmed';END IF;
 IF s#>>'{volvo,future_count}'<>'1' OR s#>>'{volvo,confirmed_loaded_paid_count}'<>'1'
 OR s#>>'{volvo,unconfirmed_past_count}'<>'1' THEN RAISE EXCEPTION 'Vehicle payments cannot be inferred from date';END IF;
 IF s#>>'{pai_mae,future_count}'<>'2' OR s#>>'{pai_mae,future_total}'<>'50'
 OR s#>>'{pai_mae,next_due}'<>'2021-01-01' OR s#>>'{pai_mae,confirmed_loaded_paid_count}'<>'0'
 THEN RAISE EXCEPTION 'Family projections must stay scheduled';END IF;
 IF (public.lts_commitment_read_state_v309(u,'2020-10-19')#>>'{cipo_396,confirmed_loaded_paid_count}')<>'1'
 OR (public.lts_commitment_read_state_v309(u,'2020-09-20')#>>'{cipo_396,confirmed_loaded_paid_count}')<>'0'
 THEN RAISE EXCEPTION 'Future payment leaked backwards';END IF;
 j:=public.lts_commitments_summary_v1(u,'2020-10-24');SELECT e INTO c FROM jsonb_array_elements(j->'commitments') e WHERE e->>'id'='cipo_396';
 IF c->>'current_documentary_debt_balance'<>'900' OR c->>'current_debt_as_of'<>'2020-09-02'
 OR c->>'documentary_remaining_scheduled_outflow'<>'300' OR c->>'remaining_scheduled_outflow_current_terms'<>'130'
 OR c->>'confirmed_paid_installments'<>'6' THEN RAISE EXCEPTION 'Dated debt or current schedule wrong: %',c;END IF;
 j:=public.lts_commitments_summary_v1(u,'2020-08-01');SELECT e INTO c FROM jsonb_array_elements(j->'commitments') e WHERE e->>'id'='cipo_396';
 IF c->'current_documentary_debt_balance'<>'null'::jsonb OR c->'remaining_events'<>'null'::jsonb OR c->'next_due'<>'null'::jsonb THEN RAISE EXCEPTION 'Future statement leaked to earlier as-of';END IF;
 w:=public.lts_browser_wealth_detail_v242();
 IF w->'commitments' IS DISTINCT FROM w#>'{financing,summary}' OR w->'documentary_commitments' IS DISTINCT FROM w#>'{financing,documentary}' THEN RAISE EXCEPTION 'Stale aliases remain';END IF;
 IF w#>'{wealth}' IS DISTINCT FROM '{"summary":{"known_debt_total":900},"cash":12.34}'::jsonb OR w#>'{rsu_summary}' IS DISTINCT FROM '{"value":56.78}'::jsonb THEN RAISE EXCEPTION 'Unrelated financial values changed';END IF;
 IF public.lts_commitment_read_state_v309(NULL,'2020-10-24')<>'{}'::jsonb
 OR public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000002','2020-10-24')<>'{}'::jsonb THEN RAISE EXCEPTION 'Owner partition wrong';END IF;
 IF has_function_privilege('anon','public.lts_commitment_read_state_v309(uuid,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_commitment_read_state_v309(uuid,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_commitment_documentary_overlay_v309(uuid,date,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Private helper exposed';END IF;
 PERFORM set_config('lts.v309.cases','14',false);
END $check$;
