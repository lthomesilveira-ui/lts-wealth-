CREATE FUNCTION public.fixture_assert(ok boolean,message text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'V386: %',message;END IF;END$$;
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-02')->>'balance_brl'='5010','pre-withdrawal dated position');
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-09')->>'balance_brl' IS NULL,'received withdrawal cannot certify zero');
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-09')#>>'{withdrawal,confirmed}'='true','canonical receipt used');
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000002','2030-01-09')->>'balance_brl'='999','other owner independent');
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000003','2030-01-09')->>'status'='position_unavailable','absent balance not zero');
DO $cases$DECLARE x text;j jsonb;BEGIN
 FOR x IN SELECT unnest(ARRAY['pending','deleted','wrong_bank','wrong_currency','wrong_owner','unconfirmed','wrong_amount']) LOOP
  UPDATE public.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000001',institution_code='341',currency='BRL',provider_deleted_at=NULL,confirmed=true,signed_amount=5010,normalized_payload='{"status":"POSTED"}';
  IF x='pending' THEN UPDATE public.lts_open_finance_staging SET normalized_payload='{"status":"PENDING"}';
  ELSIF x='deleted' THEN UPDATE public.lts_open_finance_staging SET provider_deleted_at=now();
  ELSIF x='wrong_bank' THEN UPDATE public.lts_open_finance_staging SET institution_code='000';
  ELSIF x='wrong_currency' THEN UPDATE public.lts_open_finance_staging SET currency='USD';
  ELSIF x='wrong_owner' THEN UPDATE public.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000002';
  ELSIF x='unconfirmed' THEN UPDATE public.lts_open_finance_staging SET confirmed=false;
  ELSIF x='wrong_amount' THEN UPDATE public.lts_open_finance_staging SET signed_amount=5009;END IF;
  j:=public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-09');
  PERFORM public.fixture_assert(j#>>'{withdrawal,confirmed}'='false' AND j->>'balance_brl' IS NULL AND j->>'status'='withdrawal_requires_reconciliation',x);
 END LOOP;
END;$cases$;
UPDATE public.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000001',institution_code='341',currency='BRL',provider_deleted_at=NULL,confirmed=true,signed_amount=5010,normalized_payload='{"status":"POSTED"}';
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-4000-8000-000000000022',user_id,resource_type,institution_code,currency,provider_deleted_at,posting_date,signed_amount,normalized_payload,confirmed FROM public.lts_open_finance_staging;
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-09')#>>'{withdrawal,confirmed}'='false','ambiguous duplicate receipt not summed');
DELETE FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000022';
INSERT INTO public.asset_positions VALUES('00000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000001','fgts-new','FGTS','Synthetic FGTS','2030-01-10',NULL,NULL,0,'restricted','restricted','{}',now());
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-11')->>'balance_brl'='0','explicit newer documented zero remains valid');
UPDATE public.asset_positions SET value_brl=123 WHERE id='00000000-0000-4000-8000-000000000013';
SELECT public.fixture_assert(public.lts_fgts_position_evidence_v386('00000000-0000-4000-8000-000000000001','2030-01-11')->>'balance_brl'='123','new primary position supersedes receipt');
SELECT public.fixture_assert(NOT has_function_privilege('anon','public.lts_fgts_position_evidence_v386(uuid,date)','EXECUTE') AND NOT has_function_privilege('authenticated','public.lts_fgts_position_evidence_v386(uuid,date)','EXECUTE') AND has_function_privilege('service_role','public.lts_fgts_position_evidence_v386(uuid,date)','EXECUTE'),'service-only helper');
SELECT set_config('lts.fixture_owner','00000000-0000-4000-8000-000000000001',false);
DO $reader$DECLARE j jsonb;BEGIN
 j:=public.lts_browser_wealth_detail_v3();
 PERFORM public.fixture_assert(NOT j?'schiavalli','phantom key removed including cached base');
 PERFORM public.fixture_assert(j#>>'{fgts_position,version}'='fgts-position-evidence-v386','actual existing reader carries evidence');
 PERFORM public.fixture_assert(j-'fgts_position'=(SELECT payload-'schiavalli' FROM public.fixture_reader_before),'all other reader fields exact');
END;$reader$;
SELECT public.fixture_assert((SELECT md5(pg_get_functiondef('public.lts_browser_wealth_detail_v3()'::regprocedure)))=(SELECT definition_hash FROM public.fixture_reader_after),'repeated patch leaves body exact');
SELECT '{"pass":true,"postgres":17,"cases":20,"source_and_financial_fields_unchanged":true,"excluded_asset_absent":true,"helper_service_only":true}' AS v386_native_result;
