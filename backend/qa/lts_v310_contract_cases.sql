DO $check$ DECLARE u uuid:='00000000-0000-4000-8000-000000000001';s jsonb;p record;BEGIN
 SELECT * INTO p FROM public.lts_documentary_contract_payments_v310(u,'2020-10-24');
 IF p.financial_event_id<>'00000000-0000-4000-8000-000000000502'::uuid OR p.paid_date<>'2020-10-06'
 OR p.paid_amount<>25 THEN RAISE EXCEPTION 'Existing documentary payment not reused';END IF;
 IF (SELECT count(*) FROM public.lts_documentary_contract_payments_v310(u,'2020-10-24'))<>1 THEN RAISE EXCEPTION 'Ambiguous identity';END IF;
 s:=public.lts_commitment_read_state_v309(u,'2020-10-24');
 IF s#>>'{volvo,confirmed_loaded_paid_count}'<>'1' OR s#>>'{volvo,unconfirmed_past_count}'<>'1'
 OR s#>>'{volvo,future_count}'<>'1' OR s#>>'{volvo,future_total}'<>'35'
 OR s#>>'{volvo,next_due}'<>'2020-11-05' THEN RAISE EXCEPTION 'Payment/schedule split wrong';END IF;
 IF s#>>'{volvo,realized_rows,0,due_date}'<>'2020-10-05' OR s#>>'{volvo,realized_rows,0,paid_date}'<>'2020-10-06'
 THEN RAISE EXCEPTION 'Nominal date overwritten by posting date';END IF;
 IF (public.lts_commitment_read_state_v309(u,'2020-10-05')#>>'{volvo,confirmed_loaded_paid_count}')<>'0'
 THEN RAISE EXCEPTION 'Future payment leaked backwards';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_documentary_contract_payments_v310(NULL,'2020-10-24'))
 OR EXISTS(SELECT 1 FROM public.lts_documentary_contract_payments_v310('00000000-0000-4000-8000-000000000002','2020-10-24'))
 THEN RAISE EXCEPTION 'Owner partition wrong';END IF;
 IF has_function_privilege('anon','public.lts_documentary_contract_payments_v310(uuid,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_documentary_contract_payments_v310(uuid,date)','EXECUTE')
 THEN RAISE EXCEPTION 'Private helper exposed';END IF;
END $check$;
