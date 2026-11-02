BEGIN;
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value)VALUES('itau_cofrinho_fixture_current',jsonb_build_object('as_of',current_date,'amount',875));
INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444450','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú',current_date,875,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_current"}');
DO $test$
DECLARE j jsonb:=public.lts_browser_cash_today_v178();
BEGIN
 IF(j->>'d0')::numeric<>875 OR(j#>>'{position_dates,d0}')::date<>current_date THEN RAISE EXCEPTION 'current amount and source date do not agree';END IF;
END $test$;
ROLLBACK;
SELECT 'V399 current Cofrinho amount and source date follow the same confirmation' result;
