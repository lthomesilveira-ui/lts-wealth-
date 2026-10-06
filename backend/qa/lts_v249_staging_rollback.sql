-- Execute only inside the candidate probe's rollback subtransaction.
DO $qa$
DECLARE
 u uuid:=public.lts_open_finance_pilot_owner_v1(); c record; run_id uuid; next_run uuid;
 key text; x jsonb; result jsonb; s public.lts_open_finance_staging;
 row_view record; cases jsonb:='[]'; base_events text; after_events text; rejected boolean;
BEGIN
 SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text,'')) INTO base_events
 FROM public.financial_events f WHERE user_id=u;
 FOR c IN SELECT * FROM public.lts_open_finance_connection WHERE user_id=u AND provider='pluggy'
  AND institution_code IN ('341','237','336') ORDER BY institution_code LOOP
  INSERT INTO public.lts_open_finance_sync_run(user_id,connection_id,trigger_type,status)
  VALUES(u,c.id,'manual','running') RETURNING id INTO run_id;
  key:=c.provider_connection_ref||':v249-qa-'||gen_random_uuid()::text;
  x:=jsonb_build_object('resource_type','card_transaction','provider_record_id',key,
   'provider_account_ref','synthetic-card','signed_amount',-12.34,'currency','BRL',
   'occurred_at','2026-10-03T15:00:00Z','posting_date','2026-10-03','description_raw','V249 synthetic purchase',
   'provider_updated_at','2026-10-05T15:00:00Z','raw_hash',repeat('a',64),
   'raw_payload',jsonb_build_object('operationType','PAGAMENTO','amount',12.34,'category','Shopping'),
   'normalized_payload',jsonb_build_object('item_id',c.provider_connection_ref,'provider_id',key,
    'provider_account_id','synthetic-card','amount',-12.34,'status','PENDING','last4','2222',
    'card_name','Synthetic card','institution',c.institution_name,'layer','card_consumption',
    'normalization_revision','v249-card-identity-and-layer','official_effect',false),
   'reconciliation',jsonb_build_object('classification','conflict','reason','incomplete_or_pending_provider_record','candidates','[]'::jsonb));
  IF c.institution_code='341' THEN result:=public.lts_open_finance_stage_batch_v1(u,c.id,run_id,jsonb_build_array(x));
  ELSE result:=public.lts_open_finance_stage_batch_bank_v1(u,c.id,run_id,jsonb_build_array(x)); END IF;
  IF result->>'promotion_enabled'<>'false' THEN RAISE EXCEPTION 'promotion unexpectedly enabled'; END IF;
  -- Retry creates no second observation or staged purchase.
  IF c.institution_code='341' THEN result:=public.lts_open_finance_stage_batch_v1(u,c.id,run_id,jsonb_build_array(x));
  ELSE result:=public.lts_open_finance_stage_batch_bank_v1(u,c.id,run_id,jsonb_build_array(x)); END IF;
  IF (SELECT count(*) FROM public.lts_open_finance_observation WHERE sync_run_id=run_id AND provider_record_id=key)<>1
   OR (result->>'observations_inserted')::int<>0 THEN RAISE EXCEPTION 'same-run retry duplicated'; END IF;
  rejected:=false;
  BEGIN
   IF c.institution_code='341' THEN PERFORM public.lts_open_finance_stage_batch_v1(u,c.id,run_id,jsonb_build_array(jsonb_set(x,'{normalized_payload,last4}','"3333"')));
   ELSE PERFORM public.lts_open_finance_stage_batch_bank_v1(u,c.id,run_id,jsonb_build_array(jsonb_set(x,'{normalized_payload,last4}','"3333"'))); END IF;
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='RETRY_PAYLOAD_CHANGED' THEN rejected:=true; ELSE RAISE; END IF; END;
  IF NOT rejected THEN RAISE EXCEPTION 'changed normalized retry accepted'; END IF;
  SELECT * INTO s FROM public.lts_open_finance_staging WHERE user_id=u AND provider_record_id=key;
  SELECT * INTO row_view FROM public.lts_card_source_rows_v226(u) WHERE source_id=s.id;
  IF row_view.source_id IS NULL OR row_view.is_payment OR row_view.provider_status<>'PENDING'
   OR row_view.amount<>12.34 THEN RAISE EXCEPTION 'pending consumption not preserved by card consumer'; END IF;
  -- New run, unchanged raw source, revised derived identity: re-normalize safely.
  INSERT INTO public.lts_open_finance_sync_run(user_id,connection_id,trigger_type,status)
  VALUES(u,c.id,'manual','running') RETURNING id INTO next_run;
  x:=jsonb_set(x,'{normalized_payload,last4}','"3333"');
  IF c.institution_code='341' THEN PERFORM public.lts_open_finance_stage_batch_v1(u,c.id,next_run,jsonb_build_array(x));
  ELSE PERFORM public.lts_open_finance_stage_batch_bank_v1(u,c.id,next_run,jsonb_build_array(x)); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging WHERE id=s.id AND normalized_payload->>'last4'='3333')
   OR NOT EXISTS(SELECT 1 FROM public.lts_open_finance_observation WHERE sync_run_id=next_run AND provider_record_id=key AND ingest_action='unchanged')
   OR NOT EXISTS(SELECT 1 FROM public.lts_open_finance_observation WHERE sync_run_id=run_id AND provider_record_id=key AND normalized_payload->>'last4'='2222')
   THEN RAISE EXCEPTION 'renormalization or immutable original evidence failed'; END IF;
  -- A posted update changes value, date, provider timestamp and reconciliation together.
  INSERT INTO public.lts_open_finance_sync_run(user_id,connection_id,trigger_type,status)
  VALUES(u,c.id,'manual','running') RETURNING id INTO next_run;
  x:=x||jsonb_build_object('signed_amount',-15.67,'posting_date','2026-10-04','occurred_at','2026-10-04T15:00:00Z',
   'provider_updated_at','2026-10-05T16:00:00Z','raw_hash',repeat('b',64),
   'raw_payload',jsonb_build_object('operationType','PAGAMENTO','amount',15.67,'category','Shopping'),
   'normalized_payload',(x->'normalized_payload')||jsonb_build_object('status','POSTED','amount',-15.67),
   'reconciliation',jsonb_build_object('classification','new','reason','not_found_in_consulted_lts_sources','candidates','[]'::jsonb));
  IF c.institution_code='341' THEN PERFORM public.lts_open_finance_stage_batch_v1(u,c.id,next_run,jsonb_build_array(x));
  ELSE PERFORM public.lts_open_finance_stage_batch_bank_v1(u,c.id,next_run,jsonb_build_array(x)); END IF;
  SELECT * INTO s FROM public.lts_open_finance_staging WHERE user_id=u AND provider_record_id=key;
  IF s.signed_amount<>-15.67 OR s.posting_date<>date '2026-10-04' OR s.match_status<>'normalized'
   OR s.provider_updated_at<>timestamptz '2026-10-05T16:00:00Z' OR s.promotion_status<>'blocked'
   THEN RAISE EXCEPTION 'posted snapshot retained stale economic columns'; END IF;
  SELECT * INTO row_view FROM public.lts_card_source_rows_v226(u) WHERE source_id=s.id;
  IF row_view.provider_status<>'POSTED' OR row_view.amount<>15.67 OR row_view.is_payment
   THEN RAISE EXCEPTION 'posted card consumer mismatch'; END IF;
  -- Older different raw payload cannot undo the posted state.
  INSERT INTO public.lts_open_finance_sync_run(user_id,connection_id,trigger_type,status)
  VALUES(u,c.id,'manual','running') RETURNING id INTO next_run;
  IF c.institution_code='341' THEN PERFORM public.lts_open_finance_stage_batch_v1(u,c.id,next_run,jsonb_build_array(x||jsonb_build_object('raw_hash',repeat('c',64),'provider_updated_at','2026-10-05T14:00:00Z','signed_amount',-1)));
  ELSE PERFORM public.lts_open_finance_stage_batch_bank_v1(u,c.id,next_run,jsonb_build_array(x||jsonb_build_object('raw_hash',repeat('c',64),'provider_updated_at','2026-10-05T14:00:00Z','signed_amount',-1))); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_observation WHERE sync_run_id=next_run AND provider_record_id=key AND ingest_action='stale')
   OR NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging WHERE id=s.id AND signed_amount=-15.67 AND raw_hash=repeat('b',64))
   THEN RAISE EXCEPTION 'stale update overwrote latest state'; END IF;
  -- Refund is a signed reduction of consumption, not bill payment or bank income.
  INSERT INTO public.lts_open_finance_sync_run(user_id,connection_id,trigger_type,status)
  VALUES(u,c.id,'manual','running') RETURNING id INTO next_run;
  x:=x||jsonb_build_object('signed_amount',15.67,'provider_updated_at','2026-10-05T17:00:00Z','raw_hash',repeat('d',64),
   'raw_payload',jsonb_build_object('operationType','ESTORNO','amount',-15.67,'category','Shopping'),
   'normalized_payload',(x->'normalized_payload')||jsonb_build_object('amount',15.67));
  IF c.institution_code='341' THEN PERFORM public.lts_open_finance_stage_batch_v1(u,c.id,next_run,jsonb_build_array(x));
  ELSE PERFORM public.lts_open_finance_stage_batch_bank_v1(u,c.id,next_run,jsonb_build_array(x)); END IF;
  SELECT * INTO row_view FROM public.lts_card_source_rows_v226(u) WHERE source_id=s.id;
  IF row_view.amount<>-15.67 OR row_view.is_payment THEN RAISE EXCEPTION 'refund became payment or expense debit'; END IF;
  cases:=cases||jsonb_build_array(jsonb_build_object('bank',c.institution_code,'retry',true,'changed_retry_rejected',true,
   'unchanged_raw_renormalized',true,'original_observation_preserved',true,'pending_to_posted',true,'stale_rejected',true,
   'refund_sign_preserved',true,'promotion_disabled',true));
 END LOOP;
 IF jsonb_array_length(cases)<>3 THEN RAISE EXCEPTION 'three-bank coverage incomplete'; END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text,'')) INTO after_events
 FROM public.financial_events f WHERE user_id=u;
 IF base_events IS DISTINCT FROM after_events THEN RAISE EXCEPTION 'canonical financial events changed'; END IF;
 PERFORM set_config('lts.qa_v249',jsonb_build_object('status','PASS','cases',cases,'financial_events_unchanged',true)::text,true);
END $qa$;
