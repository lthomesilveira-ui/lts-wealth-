BEGIN;
INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444448','11111111-1111-4111-8111-111111111111','FGTS','Synthetic FGTS','2020-01-01',500,'restricted',false,'{}');
INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444449','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2020-01-01',1000,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20200101"}');
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value)VALUES('itau_cofrinho_fixture_20200101','{"as_of":"2020-01-01","amount":1000}'),('morgan_available_fixture_20200101','{"as_of":"2020-01-01","total_available_brl":300}');
INSERT INTO public.lts_future_liquidity_effective_v290 VALUES('11111111-1111-4111-8111-111111111111','RSU',true,current_date+5,3,80,100),('11111111-1111-4111-8111-111111111111','Cash RSU',true,current_date+10,2,50,70);
DO $test$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';source jsonb;old jsonb;new jsonb;n integer;
BEGIN
 SELECT jsonb_build_object('days',jsonb_agg(jsonb_build_object('date',current_date+i,'fix86_columns',jsonb_build_object('saldo_final',77-i*2,'liq_d0_1_recurso',1000))))INTO source FROM generate_series(0,20)i;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY flow_date)INTO old FROM public.qa_ladder_reference_v399(u,current_date,current_date+20,source)x;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY flow_date)INTO new FROM public.lts_dashboard_cash_ladder_from_flow_v229(u,current_date,current_date+20,source)x;
 IF old IS DISTINCT FROM new THEN RAISE EXCEPTION 'ladder changed independently calculated resources or vesting dates';END IF;
 IF(new#>>'{0,fgts_projected}')::numeric<>500 OR(new#>>'{0,rsu_vested_today}')::numeric<>300 THEN RAISE EXCEPTION 'independent FGTS or shares missing';END IF;
 SELECT jsonb_build_object('days',jsonb_agg(jsonb_build_object('date',current_date+i,'fix86_columns',jsonb_build_object('saldo_final',77-i*2,'liq_d0_1_recurso',1000))))INTO source FROM generate_series(0,1825)i;
 SELECT count(*)INTO n FROM public.lts_dashboard_cash_ladder_from_flow_v229(u,current_date,current_date+1825,source);
 IF n<>1826 THEN RAISE EXCEPTION 'long ladder lost days';END IF;
END $test$;
ROLLBACK;
SELECT 'V399 ladder preserves original reference arithmetic, FGTS and scheduled awards' result;
