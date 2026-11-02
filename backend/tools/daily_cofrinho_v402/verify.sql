SET TIME ZONE 'America/Sao_Paulo';
CREATE TABLE public.qa_checks_v402(name text PRIMARY KEY,passed boolean NOT NULL CHECK(passed));
CREATE FUNCTION public.qa_assert_v402(p_name text,p_ok boolean)RETURNS void LANGUAGE sql AS $function$
 INSERT INTO public.qa_checks_v402 VALUES(p_name,coalesce(p_ok,false));
$function$;
SELECT public.qa_assert_v402('verified_component_sum',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-01')=1000);
SELECT public.qa_assert_v402('late_linked_redemption_once',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-02')=910);
SELECT public.qa_assert_v402('prior_redemptions_already_in_snapshot',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-03')=720);
SELECT public.qa_assert_v402('next_daily_valuation',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-04')=725);
SELECT public.qa_assert_v402('explicit_owner_position_kept',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-05')=740);
SELECT public.qa_assert_v402('next_provider_day_automatically_used',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-06')=760);
SELECT public.qa_assert_v402('provider_future_date_never_used_as_position_day',public.lts_cofrinho_provider_position_v402('11111111-1111-4111-8111-111111111111','2020-01-04')->>'snapshot_date'='2020-01-04');
SELECT public.qa_assert_v402('same_collection_two_components',jsonb_array_length(public.lts_cofrinho_provider_position_v402('11111111-1111-4111-8111-111111111111','2020-01-04')->'components')=2);
SELECT public.qa_assert_v402('foreign_owner_no_position',NOT(public.lts_cofrinho_provider_position_v402('22222222-2222-4222-8222-222222222222','2020-01-04')->>'has_position')::boolean);
SELECT public.qa_assert_v402('null_owner_no_position',NOT(public.lts_cofrinho_provider_position_v402(NULL,'2020-01-04')->>'has_position')::boolean);
SELECT public.qa_assert_v402('null_date_no_position',NOT(public.lts_cofrinho_provider_position_v402('11111111-1111-4111-8111-111111111111',NULL)->>'has_position')::boolean);
SELECT public.qa_assert_v402('pre_boundary_legacy_preserved',public.lts_cofrinho_composition_v399('11111111-1111-4111-8111-111111111111','2019-12-30')=public.lts_cofrinho_documentary_composition_v402('11111111-1111-4111-8111-111111111111','2019-12-30'));
SELECT public.qa_assert_v402('recorded_late_move_shown_once',jsonb_array_length(public.lts_cofrinho_composition_v399('11111111-1111-4111-8111-111111111111','2020-01-02')->'recorded_movements')=1);
SELECT public.qa_assert_v402('late_receipt_marked_represented',(public.lts_cofrinho_composition_v399('11111111-1111-4111-8111-111111111111','2020-01-02')#>>'{bank_redemptions,0,represented_by_recorded_movement}')::boolean);
SELECT public.qa_assert_v402('old_date_not_rewritten_by_later_source',public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111','2020-01-01')=1000);
SELECT public.qa_assert_v402('batched_daily_parity',NOT EXISTS(
 SELECT 1 FROM public.lts_dated_d0_series_v399('11111111-1111-4111-8111-111111111111','2020-01-01','2020-01-15')
 WHERE d0_resource IS DISTINCT FROM public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111',flow_date)));
SELECT public.qa_assert_v402('current_bridge_matches_core',
 (public.lts_current_evidence_position_v2('11111111-1111-4111-8111-111111111111')->>'liquid_d0_assets')::numeric
 =public.lts_cofrinho_effective_locked_v245('11111111-1111-4111-8111-111111111111',current_date));
SELECT public.qa_assert_v402('no_financial_or_source_rows_changed',
 (SELECT data FROM public.qa_protected_v402)=jsonb_build_object(
 'assets',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.asset_positions a),
 'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.financial_events e),
 'movements',(SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM public.lts_liquidity_movement m),
 'mapping',(SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM public.lts_open_finance_resource_map m),
 'observations',(SELECT jsonb_agg(to_jsonb(o) ORDER BY id) FROM public.lts_open_finance_observation o)));

DO $cases$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';base jsonb;got jsonb;mutation text;
BEGIN
 base:=public.lts_cofrinho_provider_position_v402(u,'2020-01-04');
 FOREACH mutation IN ARRAY ARRAY['missing','wrong_owner','wrong_item','wrong_code','wrong_currency','negative',
  'bad_net_type','bad_normalized','bad_timestamp','future_timestamp','spread','failed_run'] LOOP
  BEGIN
   IF mutation='missing' THEN DELETE FROM public.lts_open_finance_observation WHERE id=md5('2020-01-04b')::uuid;
   ELSIF mutation='wrong_owner' THEN UPDATE public.lts_open_finance_observation SET user_id='22222222-2222-4222-8222-222222222222' WHERE id=md5('2020-01-04b')::uuid;
   ELSIF mutation='failed_run' THEN UPDATE public.lts_open_finance_sync_run SET status='failed' WHERE id=md5('2020-01-04')::uuid;
   ELSE
    UPDATE public.lts_open_finance_observation SET raw_payload=raw_payload||CASE mutation
     WHEN 'wrong_item' THEN '{"itemId":"unrelated-item"}'::jsonb
     WHEN 'wrong_code' THEN '{"code":"OTHER"}'::jsonb
     WHEN 'wrong_currency' THEN '{"currencyCode":"USD"}'::jsonb
     WHEN 'negative' THEN '{"balance":-1}'::jsonb
     WHEN 'bad_net_type' THEN '{"balance":"invalid"}'::jsonb
     WHEN 'bad_timestamp' THEN '{"updatedAt":"invalid"}'::jsonb
     WHEN 'future_timestamp' THEN '{"updatedAt":"2099-01-01T00:00:00Z"}'::jsonb
     WHEN 'spread' THEN '{"updatedAt":"2020-01-04T01:00:00Z"}'::jsonb
     ELSE '{}'::jsonb END,
     normalized_payload=CASE WHEN mutation='bad_normalized' THEN '{"amount_semantics":"net_valuation","net_valuation":"invalid"}'::jsonb ELSE normalized_payload END
    WHERE id=md5('2020-01-04b')::uuid;
   END IF;
   got:=public.lts_cofrinho_provider_position_v402(u,'2020-01-04');
   IF (got->>'snapshot_brl')::numeric<>720 OR got->>'snapshot_date'<>'2020-01-03' THEN
    RAISE EXCEPTION 'invalid collection accepted: %',mutation;
   END IF;
   RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
  EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;
  END;
  PERFORM public.qa_assert_v402('reject_'||mutation,true);
 END LOOP;
 PERFORM public.qa_assert_v402('mutation_rollback_exact',public.lts_cofrinho_provider_position_v402(u,'2020-01-04')=base);
 BEGIN
  UPDATE public.lts_validated_lock_registry SET superseded_at=now() WHERE lock_key='itau_cofrinho_fixture_20191231';
  IF public.lts_cofrinho_effective_locked_v245(u,'2020-01-02')<>910 THEN
   RAISE EXCEPTION 'historical provider observation incorrectly requires a later documentary anchor';END IF;
  IF (SELECT d0_resource FROM public.lts_dated_d0_series_v399(u,'2020-01-02','2020-01-02'))<>910 THEN
   RAISE EXCEPTION 'batched history ignored the provider observation';END IF;
  RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
 EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;END;
 PERFORM public.qa_assert_v402('provider_before_documentary_anchor',true);
 BEGIN
  UPDATE public.lts_open_finance_resource_map SET reconciliation_status='candidate' WHERE provider_resource_id='component-b';
  IF (public.lts_cofrinho_provider_position_v402(u,'2020-01-04')->>'has_position')::boolean THEN
   RAISE EXCEPTION 'partial verified map accepted';END IF;
  RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
 EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;END;
 PERFORM public.qa_assert_v402('partial_mapping_not_accepted',true);
 BEGIN
  DELETE FROM public.lts_open_finance_resource_map WHERE provider_resource_id='component-b';
  IF (public.lts_cofrinho_provider_position_v402(u,'2020-01-04')->>'has_position')::boolean THEN
   RAISE EXCEPTION 'deleted mapping silently changed the component set';END IF;
  RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
 EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;END;
 PERFORM public.qa_assert_v402('missing_mapping_not_accepted',true);
 BEGIN
  INSERT INTO public.lts_liquidity_movement VALUES('66666666-6666-4666-8666-666666666661',u,
   '44444444-4444-4444-8444-444444444450',NULL,'2020-01-04','active','application',-10,10,'{}');
  got:=public.lts_cofrinho_composition_v399(u,'2020-01-04');
  IF (got->>'complete')::boolean OR got->>'available_brl' IS NOT NULL THEN RAISE EXCEPTION 'ambiguous same-day movement accepted';END IF;
  IF (SELECT d0_resource FROM public.lts_dated_d0_series_v399(u,'2020-01-04','2020-01-04')) IS NOT NULL THEN
   RAISE EXCEPTION 'unknown balance silently converted to zero';END IF;
  RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
 EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;END;
 PERFORM public.qa_assert_v402('ambiguous_same_day_move_not_guessed',true);
 BEGIN
  UPDATE public.lts_open_finance_observation SET raw_payload=raw_payload||'{"status":"TOTAL_WITHDRAWAL","balance":0,"code":" ","updatedAt":"2020-01-01T18:00:00Z"}',
   normalized_payload='{"amount_semantics":"net_valuation","net_valuation":0}' WHERE id=md5('2020-01-04b')::uuid;
  got:=public.lts_cofrinho_provider_position_v402(u,'2020-01-04');
  IF (got->>'snapshot_brl')::numeric<>205 THEN RAISE EXCEPTION 'explicit withdrawn zero rejected';END IF;
  RAISE EXCEPTION USING ERRCODE='P0402',MESSAGE='rollback mutation';
 EXCEPTION WHEN SQLSTATE 'P0402' THEN NULL;END;
 PERFORM public.qa_assert_v402('explicit_withdrawn_component_zero',true);
END $cases$;

SELECT public.qa_assert_v402('anonymous_direct_execution_denied',NOT has_function_privilege('anon','public.lts_cofrinho_provider_position_v402(uuid,date)','EXECUTE'));
SELECT public.qa_assert_v402('authenticated_direct_execution_denied',NOT has_function_privilege('authenticated','public.lts_cofrinho_provider_position_v402(uuid,date)','EXECUTE'));
SET ROLE service_role;
SELECT public.lts_cofrinho_provider_position_v402('11111111-1111-4111-8111-111111111111','2020-01-04');
RESET ROLE;
SELECT public.qa_assert_v402('service_role_actual_execution',true);
-- Enough older indexed collections to expose an accidental history scan per day.
INSERT INTO public.lts_open_finance_sync_run
SELECT md5('old-run-'||g)::uuid,'11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333','success',
 '2018-01-01'::timestamptz+g*interval '1 hour',
 '2018-01-01'::timestamptz+g*interval '1 hour'+interval '1 minute'
FROM generate_series(1,1200)g;
ANALYZE public.lts_open_finance_sync_run;
SET statement_timeout='12s';
DO $performance$
DECLARE started timestamptz:=clock_timestamp();n integer;elapsed numeric;
BEGIN
 SELECT count(*) INTO n FROM public.lts_dated_d0_series_v399(
  '11111111-1111-4111-8111-111111111111',current_date,current_date+1520);
 elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
 IF n<>1521 THEN RAISE EXCEPTION 'future coverage missing';END IF;
 RAISE NOTICE 'V402_FUTURE_PERFORMANCE rows=% milliseconds=%',n,elapsed;
 PERFORM public.qa_assert_v402('future_range_1521_days_indexed',n=1521);
END $performance$;
RESET statement_timeout;
CREATE SEQUENCE public.qa_provider_calls_v402;
CREATE SEQUENCE public.qa_receipt_calls_v402;
DO $instrument$
DECLARE d text;
BEGIN
 d:=pg_get_functiondef('public.lts_cofrinho_provider_position_v402(uuid,date)'::regprocedure);
 EXECUTE replace(d,'FUNCTION public.lts_cofrinho_provider_position_v402(',
  'FUNCTION public.qa_provider_original_v402(');
 d:=pg_get_functiondef('public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)'::regprocedure);
 EXECUTE replace(d,'FUNCTION public.lts_cofrinho_bank_redemptions_v381(',
  'FUNCTION public.qa_receipt_original_v402(');
END $instrument$;
CREATE OR REPLACE FUNCTION public.lts_cofrinho_provider_position_v402(p_user_id uuid,p_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $function$
BEGIN
 PERFORM nextval('public.qa_provider_calls_v402');
 RETURN public.qa_provider_original_v402(p_user_id,p_date);
END $function$;
CREATE OR REPLACE FUNCTION public.lts_cofrinho_bank_redemptions_v381(p_user_id uuid,p_after date,p_through date)
RETURNS TABLE(staging_id uuid,event_date date,bank_amount_brl numeric,
 represented_by_recorded_movement boolean,representation_conflict boolean,
 unrepresented_asset_delta_brl numeric,raw_hash text,provider_record_id text)
LANGUAGE plpgsql STABLE AS $function$
BEGIN
 PERFORM nextval('public.qa_receipt_calls_v402');
 RETURN QUERY SELECT * FROM public.qa_receipt_original_v402(p_user_id,p_after,p_through);
END $function$;
SELECT count(*) FROM public.lts_dated_d0_series_v399(
 '11111111-1111-4111-8111-111111111111',current_date,current_date+1520);
SELECT public.qa_assert_v402('provider_read_once_for_future_range',
 (SELECT last_value=1 AND is_called FROM public.qa_provider_calls_v402));
SELECT public.qa_assert_v402('bank_receipts_read_once_for_future_range',
 (SELECT last_value=1 AND is_called FROM public.qa_receipt_calls_v402));
SELECT jsonb_build_object('passed',count(*),'all_passed',bool_and(passed),'native_postgres_17',true,'financial_data','synthetic only') FROM public.qa_checks_v402;
