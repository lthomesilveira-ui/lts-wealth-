BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
DO $test$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111'; n numeric; before_count bigint;
BEGIN
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03') IS DISTINCT FROM 700::numeric THEN
  RAISE EXCEPTION 'represented receipt was counted twice or missing receipt was ignored'; END IF;
 IF (SELECT count(*) FROM public.lts_cofrinho_bank_redemptions_v381(u,'2030-01-01','2030-01-03') WHERE represented_by_recorded_movement)<>1 THEN RAISE EXCEPTION 'source-linked receipt was not identified';END IF;
 IF (SELECT effective_value_brl FROM public.lts_asset_position_effective_v1(u,'2030-01-03') WHERE asset_name='Cofrinho Itaú') IS DISTINCT FROM 700::numeric THEN RAISE EXCEPTION 'effective-asset reader disagrees';END IF;
 IF (SELECT effective_value_brl FROM public.lts_asset_position_effective_v1(u,'2030-01-03') WHERE asset_name='Other asset') IS DISTINCT FROM 500::numeric THEN RAISE EXCEPTION 'other asset changed';END IF;
 IF public.lts_cofrinho_effective_locked_v245('22222222-2222-4222-8222-222222222222','2030-01-03') IS NOT NULL THEN RAISE EXCEPTION 'global anchor leaked to unrelated owner';END IF;
 SELECT count(*) INTO before_count FROM public.financial_events;
 FOR i IN 1..3 LOOP PERFORM public.lts_cofrinho_effective_locked_v245(u,'2030-01-03');END LOOP;
 IF (SELECT count(*) FROM public.financial_events)<>before_count OR (SELECT count(*) FROM public.lts_liquidity_movement)<>1 THEN RAISE EXCEPTION 'read created financial rows';END IF;

 -- Identical date/amount with a different provider identity is another receipt.
 PERFORM public.qa_receipt('55555555-5555-4555-8555-555555555554','2030-01-03',200);
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03') IS DISTINCT FROM 500::numeric THEN RAISE EXCEPTION 'distinct source was paired by value/date';END IF;
 DELETE FROM public.lts_open_finance_staging WHERE id='55555555-5555-4555-8555-555555555554';

 -- Each excluded variant is evaluated without changing the valid source.
 PERFORM public.qa_receipt('55555555-5555-4555-8555-555555555555','2030-01-03',50);
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"') WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'pending source applied';END IF;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"POSTED"'),provider_deleted_at=now() WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'deleted source applied';END IF;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=NULL,institution_code='237' WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'wrong bank applied';END IF;
 UPDATE public.lts_open_finance_staging SET institution_code='341',provider_account_ref='another-account' WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'wrong account applied';END IF;
 UPDATE public.lts_open_finance_staging SET provider_account_ref='synthetic-account',user_id='22222222-2222-4222-8222-222222222222' WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'wrong owner applied';END IF;
 UPDATE public.lts_open_finance_staging SET user_id=u,description_raw='PIX COFRINHOS' WHERE id='55555555-5555-4555-8555-555555555555';
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'merchant text inferred as redemption';END IF;
 DELETE FROM public.lts_open_finance_staging WHERE id='55555555-5555-4555-8555-555555555555';
 PERFORM public.qa_receipt('55555555-5555-4555-8555-555555555556','2030-01-09',50);
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'future receipt applied early';END IF;

 -- A later owner-confirmed balance includes previous receipts already.
 INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value) VALUES('itau_cofrinho_fixture_20300104','{"as_of":"2030-01-04","amount":750}');
 INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444446',u,'cash_investment','Cofrinho Itaú','2030-01-04',750,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20300104"}');
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-04')<>750 OR public.lts_cofrinho_effective_locked_v245(u,'2030-01-03')<>700 THEN RAISE EXCEPTION 'dated snapshot changed prior date or repeated its receipts';END IF;
 PERFORM public.qa_receipt('55555555-5555-4555-8555-555555555557','2030-01-05',30);
 IF public.lts_cofrinho_effective_locked_v245(u,'2030-01-05')<>720 THEN RAISE EXCEPTION 'receipt after new snapshot ignored';END IF;

 -- A conflicting explicit link is reported, never guessed from proximity.
 UPDATE public.lts_liquidity_movement SET bank_delta_brl=99,asset_delta_brl=-99 WHERE id='66666666-6666-4666-8666-666666666666';
 IF NOT (SELECT representation_conflict AND unrepresented_asset_delta_brl IS NULL FROM public.lts_cofrinho_bank_redemptions_v381(u,'2030-01-01','2030-01-03') WHERE staging_id='55555555-5555-4555-8555-555555555552') THEN RAISE EXCEPTION 'conflicting source link hidden';END IF;
 IF has_function_privilege('anon','public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)','execute')
 OR has_function_privilege('authenticated','public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)','execute') THEN RAISE EXCEPTION 'new private helper exposed';END IF;
 IF NOT has_function_privilege('service_role','public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)','execute') THEN RAISE EXCEPTION 'service reader inaccessible';END IF;
END $test$;
ROLLBACK;
SELECT 'V381 PostgreSQL17 documented-redemption checks passed' result;
