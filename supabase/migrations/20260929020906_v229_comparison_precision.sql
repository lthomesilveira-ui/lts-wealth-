CREATE POLICY service_cache_only ON public.lts_v229_read_cache FOR ALL TO service_role USING(true) WITH CHECK(true);
DO $$ DECLARE definition text; f record; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_expenses_v229(date,date)'::regprocedure);
 definition:=replace(definition,'''last_12m'',(select last_12m from comparison)',
  '''last_12m'',(select case when (date_trunc(''month'',p_to)-interval ''11 months'')::date>=date ''2013-10-10'' then round(last_12m,2) end from comparison)');
 definition:=replace(definition,'''current_total'',current_total,''previous_total'',previous_total',
  '''current_total'',round(current_total,2),''previous_total'',round(previous_total,2)');
 EXECUTE definition;
 FOR f IN SELECT oid::regprocedure signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE '%v229%' LOOP
  EXECUTE format('ALTER FUNCTION %s SET search_path TO ''''',f.signature);
 END LOOP;
END $$;
