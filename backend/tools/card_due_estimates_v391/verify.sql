DO $verify$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';other uuid:='00000000-0000-4000-8000-000000000002';
 base jsonb:='{"version":"card-cycles-v226","complete":true,"active_billing_accounts":1,"cards":[{"family":"c6","bank":"Banco fictício","name":"Cartão fictício","last4":"0000","cycles":[{"month":"2027-06-01","due_date":null,"amount":12.34,"basis":"derived_current_installments","items":[{"description":"Parcela fictícia","amount":12.34,"provider_status":"PROJECTED","category":"Serviços","last4":"0000"}]},{"month":"2027-09-01","due_date":null,"amount":4.56,"basis":"derived_current_installments","items":[{"description":"Outra parcela fictícia","amount":4.56,"provider_status":"PROJECTED","category":"Serviços","last4":"0000"}]}]},{"family":"itau_mastercard","bank":"Outro banco fictício","last4":"0001","cycles":[{"month":"2027-06-01","due_date":"2027-06-20","amount":99,"basis":"bank_document_composition","invoice_source_id":"invented-official"}]}]}';
 source_proof jsonb;result jsonb;official jsonb;cache_before bigint;
BEGIN
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(u,base)=base,'empty table is exact identity');
 SELECT jsonb_build_object('schema','personal-card-due-estimate-v391','provider_account_ref','invented-account',
  'source_invoice_rows',jsonb_agg(jsonb_build_object('source_id',id,'due_date',normalized_payload->>'due_date')ORDER BY id),
  'non_business_dates',jsonb_build_array('2027-01-01','2027-02-08','2027-02-09','2027-03-26','2027-04-21','2027-05-01','2027-05-27','2027-07-09','2027-09-07','2027-10-12','2027-11-02','2027-11-15','2027-11-20','2027-12-25'))
 INTO source_proof FROM public.lts_open_finance_staging WHERE user_id=u;
 SELECT e.epoch INTO cache_before FROM public.lts_read_cache_epoch_v242 e;
 INSERT INTO public.lts_card_due_estimate_v391(user_id,family,reference_month,nominal_due_date,due_date,evidence)
 VALUES(u,'c6','2027-06-01','2027-06-05','2027-06-07',source_proof),(u,'c6','2027-09-01','2027-09-05','2027-09-06',source_proof);
 PERFORM public.qa_v391_assert((SELECT e.epoch=cache_before+1 FROM public.lts_read_cache_epoch_v242 e),'one statement invalidates every prepared reader');
 result:=public.lts_card_due_overlay_v290(u,base);
 PERFORM public.qa_v391_assert(result#>>'{cards,0,cycles,0,due_date}'='2027-06-07','Saturday rolls to Monday');
 PERFORM public.qa_v391_assert(result#>>'{cards,0,cycles,1,due_date}'='2027-09-06','Sunday rolls before the Tuesday holiday');
 PERFORM public.qa_v391_assert(result#>>'{cards,0,cycles,0,due_date_basis}'='received_personal_invoice_estimate','estimate has its own basis');
 PERFORM public.qa_v391_assert(result#>'{cards,0,cycles,0,due_estimate_owner_confirmed}'='false'::jsonb,'never owner-confirmed');
 PERFORM public.qa_v391_assert(result#>'{cards,0,cycles,0,official_invoice_received}'='false'::jsonb,'never official invoice');
 PERFORM public.qa_v391_assert(result#>'{cards,0,cycles,0,amount}'=base#>'{cards,0,cycles,0,amount}' AND result#>'{cards,0,cycles,0,items}'=base#>'{cards,0,cycles,0,items}','amount and installment identities exact');
 PERFORM public.qa_v391_assert(result#>'{cards,1}'=base#>'{cards,1}','unrelated bank unchanged');
 INSERT INTO public.qa_v391_output VALUES('valid',result);
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(other,base)=base,'no cross-owner estimates');
 official:=jsonb_set(jsonb_set(base,'{cards,0,cycles,0,due_date}','"2027-06-20"'),'{cards,0,cycles,0,invoice_source_id}'::text[],'"invented-official"');
 result:=public.lts_card_due_overlay_v290(u,official);
 PERFORM public.qa_v391_assert(result#>'{cards,0,cycles,0}'=official#>'{cards,0,cycles,0}','received date wins');
 INSERT INTO public.qa_v391_output VALUES('official',result);
 INSERT INTO public.lts_card_due_rule_v290 VALUES(u,'c6','2027-06-01',20,now(),'invented-owner-confirmation');
 result:=public.lts_card_due_overlay_v290(u,base);
 PERFORM public.qa_v391_assert(result#>>'{cards,0,cycles,0,due_date}'='2027-06-20' AND result#>>'{cards,0,cycles,0,due_date_basis}'='owner_confirmed_cycle_rule','explicit owner rule wins');
 DELETE FROM public.lts_card_due_rule_v290 WHERE user_id=u;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_build_object('due_date','2026-01-06') WHERE id='00000000-0000-4000-8000-000000000001';
 result:=public.lts_card_due_overlay_v290(u,base);
 PERFORM public.qa_v391_assert(result->'complete'='false'::jsonb AND result#>'{cards,0,cycles,0,due_date}'='null'::jsonb,'source drift fails closed');
 PERFORM public.qa_v391_assert(result#>'{cards,0,cycles,0,amount}'=base#>'{cards,0,cycles,0,amount}','source failure never zeros the amount');
 INSERT INTO public.qa_v391_output VALUES('invalid',result);
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_build_object('due_date','2026-01-05') WHERE id='00000000-0000-4000-8000-000000000001';
 UPDATE public.lts_card_due_estimate_v391 SET due_date='2027-06-08' WHERE user_id=u AND reference_month='2027-06-01';
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(u,base)->'complete'='false'::jsonb,'cannot skip the first business day');
 UPDATE public.lts_card_due_estimate_v391 SET due_date='2027-06-07',evidence=jsonb_set(evidence,'{source_invoice_rows}',jsonb_build_array(evidence#>'{source_invoice_rows,0}',evidence#>'{source_invoice_rows,0}',evidence#>'{source_invoice_rows,2}')) WHERE user_id=u AND reference_month='2027-06-01';
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(u,base)->'complete'='false'::jsonb,'duplicates cannot corroborate a rule');
 UPDATE public.lts_card_due_estimate_v391 SET evidence=source_proof WHERE user_id=u;
 INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000004',u,'336','invoice','BRL',NULL,'invented-account','{"due_date":"2026-04-10"}');
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(u,base)->'complete'='false'::jsonb,'later issuer date change invalidates older estimates');
 DELETE FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000004';
 PERFORM public.qa_v391_assert(public.lts_card_due_overlay_v290(u,base)=(SELECT payload FROM public.qa_v391_output WHERE label='valid'),'restored exact evidence reproduces the result');
 PERFORM public.qa_v391_assert(NOT has_table_privilege('authenticated','public.lts_card_due_estimate_v391','INSERT') AND NOT has_table_privilege('anon','public.lts_card_due_estimate_v391','SELECT'),'no public writer or anonymous reader');
 RAISE NOTICE 'V391 native proof passed: source validation, owner/official precedence, cache epoch, unchanged money, isolation and calendar';
END $verify$;
SET ROLE authenticated;
SELECT public.qa_v391_assert((SELECT count(*)=2 FROM public.lts_card_due_estimate_v391),'own rows visible with RLS');
SELECT public.qa_v391_assert((SELECT count(*)=0 FROM public.lts_card_due_estimate_v391 WHERE user_id='00000000-0000-4000-8000-000000000002'),'other owner invisible with RLS');
RESET ROLE;
