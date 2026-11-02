BEGIN;
DO $test$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';n bigint;
BEGIN
 -- Compare the batch against the pre-existing independent effective-asset reader.
 SELECT count(*)INTO n FROM public.lts_dated_d0_series_v399(u,'2029-12-28','2030-01-10')s
 CROSS JOIN LATERAL(SELECT coalesce(sum(effective_value_brl)FILTER(WHERE liquidity_class='D+0'AND is_available_now),0)v FROM public.lts_asset_position_effective_v1(u,s.flow_date))r
 WHERE s.d0_resource IS DISTINCT FROM r.v;
 IF n<>0 THEN RAISE EXCEPTION 'batch disagrees with independent dated asset reader';END IF;
 INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444447',u,'other_cash','Separate available asset','2030-01-02',50,'D+0',true,'{}');
 IF (SELECT d0_resource FROM public.lts_dated_d0_series_v399(u,'2030-01-03','2030-01-03'))<>750 THEN RAISE EXCEPTION 'another D0 asset was discarded';END IF;
 IF (SELECT count(*)FROM public.lts_dated_d0_series_v399(u,'2030-01-01','2034-12-31'))<>1826 THEN RAISE EXCEPTION 'long range missing days';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_dated_d0_series_v399('22222222-2222-4222-8222-222222222222','2030-01-01','2030-01-10')WHERE d0_resource<>0)THEN RAISE EXCEPTION 'owner scope lost';END IF;
 IF has_function_privilege('anon','public.lts_dated_d0_series_v399(uuid,date,date)','execute')OR has_function_privilege('authenticated','public.lts_dated_d0_series_v399(uuid,date,date)','execute')THEN RAISE EXCEPTION 'batch helper exposed';END IF;
END $test$;
ROLLBACK;
SELECT 'V399 independent dated parity, multiple D0 assets, owner scope and five-year range passed' result;
