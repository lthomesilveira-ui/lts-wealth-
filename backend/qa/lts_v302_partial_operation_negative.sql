-- Private administrative trial only, with the patch installed in BEGIN/ROLLBACK.
-- lts.v302.input is the reviewed private manifest. lts.v302.operation_body is
-- the trusted DO block read from our operation file, not data from a source.
DO $negative$
DECLARE m jsonb:=current_setting('lts.v302.input')::jsonb;test_manifest jsonb;c jsonb;path text[];
 code text:=current_setting('lts.v302.operation_body');n integer:=0;err text;before_event jsonb;future_source jsonb;
BEGIN
 SELECT to_jsonb(f) INTO STRICT before_event FROM public.financial_events f
 WHERE user_id=public.lts_open_finance_pilot_owner_v1() AND id=(m->>'event_id')::uuid;
 FOR c IN SELECT x FROM jsonb_array_elements($cases$[
 {"name":"wrong_source_hash","path":["bank_raw_hash"],"value":"invalid","error":"Original confirmed obligation"},
 {"name":"wrong_event_hash","path":["event_hash"],"value":"invalid","error":"Original confirmed obligation"},
 {"name":"future_source_is_not_past_settlement","path":["bank_source_id"],"value":null,"error":"Original confirmed obligation"},
 {"name":"missing_partial_confirmation","path":["partial_evidence_id"],"value":"00000000-0000-0000-0000-000000000000","error":"query returned no rows"},
 {"name":"different_schedule_payee","path":["schedule_document","payee"],"value":"Outra instituição","error":"evidence is incomplete"},
 {"name":"different_schedule_date","path":["schedule_document","date"],"value":"2099-01-01","error":"evidence is incomplete"},
 {"name":"different_schedule_amount","path":["schedule_document","amount"],"value":0.01,"error":"evidence is incomplete"},
 {"name":"unrelated_schedule_file","path":["schedule_document","file_name"],"value":"not-confirmed.png","error":"evidence is incomplete"},
 {"name":"no_source_document_identity","path":["schedule_document","library_file_id"],"value":"","error":"evidence is incomplete"}
 ]$cases$::jsonb)x LOOP
  SELECT array_agg(x ORDER BY ord) INTO path FROM jsonb_array_elements_text(c->'path') WITH ORDINALITY p(x,ord);
  test_manifest:=jsonb_set(m,path,c->'value',true);err:=NULL;
  IF c->>'name'='future_source_is_not_past_settlement' THEN
   IF NOT m ? 'separate_future_source_id' THEN CONTINUE;END IF;
   SELECT jsonb_build_object('id',s.id,'raw_hash',s.raw_hash) INTO STRICT future_source
   FROM public.lts_open_finance_staging s WHERE s.user_id=public.lts_open_finance_pilot_owner_v1()
    AND s.id=(m->>'separate_future_source_id')::uuid AND s.posting_date>current_date
    AND s.normalized_payload->>'status'='PENDING';
   test_manifest:=m||jsonb_build_object('bank_source_id',future_source->>'id','bank_raw_hash',future_source->>'raw_hash');
  END IF;
  BEGIN
   PERFORM set_config('lts.v302.input',test_manifest::text,true);
   EXECUTE code;
  EXCEPTION WHEN OTHERS THEN err:=SQLERRM;
  END;
  IF err IS NULL OR strpos(lower(err),lower(c->>'error'))=0 THEN
   RAISE EXCEPTION 'Wrong rejection for %: %',c->>'name',err;
  END IF;
  IF (SELECT to_jsonb(f) FROM public.financial_events f WHERE user_id=public.lts_open_finance_pilot_owner_v1()
   AND id=(m->>'event_id')::uuid) IS DISTINCT FROM before_event
  OR EXISTS(SELECT 1 FROM public.lts_realized_bank_event_v238 WHERE user_id=public.lts_open_finance_pilot_owner_v1()
   AND financial_event_id=(m->>'event_id')::uuid)
  THEN RAISE EXCEPTION 'A rejected operation retained financial mutations';END IF;
  n:=n+1;
 END LOOP;
 PERFORM set_config('lts.v302.input',m::text,true);
 PERFORM set_config('lts.v302.negative_receipt',jsonb_build_object('cases',n,'passed',n,'rejected_changes_rolled_back',true)::text,true);
END $negative$;
