CREATE FUNCTION public.qa_numeric_same_v411(a jsonb,b jsonb) RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE r record;i integer;
BEGIN
 IF jsonb_typeof(a)='number' THEN RETURN a IS NOT DISTINCT FROM b; END IF;
 IF jsonb_typeof(a)='object' THEN
  FOR r IN SELECT key,value FROM jsonb_each(a) LOOP
   IF NOT public.qa_numeric_same_v411(r.value,b->r.key) THEN RETURN false;END IF;
  END LOOP;
 ELSIF jsonb_typeof(a)='array' THEN
  IF jsonb_array_length(a) IS DISTINCT FROM jsonb_array_length(b) THEN RETURN false;END IF;
  FOR i IN 0..jsonb_array_length(a)-1 LOOP
   IF NOT public.qa_numeric_same_v411(a->i,b->i) THEN RETURN false;END IF;
  END LOOP;
 END IF;
 RETURN true;
END$$;

CREATE FUNCTION public.qa_outputs_v411(u uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f jsonb;r jsonb;
BEGIN
 PERFORM set_config('test.user_id',u::text,true);
 f:=public.lts_daily_flow_fix86_v14(u,current_date,current_date+40);
 r:=jsonb_build_object(
  'wealth2',public.lts_browser_wealth_detail_v2(),
  'wealth3',public.lts_browser_wealth_detail_v3(),
  'wealth4',public.lts_browser_wealth_detail_v4(),
  'provenance',lts_award_private.provenance_v183(),
  'flow19',public.lts_daily_flow_fix86_v19(u,current_date,current_date+40),
  'flow20',public.lts_daily_flow_fix86_v20(u,current_date,current_date+40),
  'dynamic',(SELECT jsonb_agg(to_jsonb(d)ORDER BY flow_date)FROM public.lts_flow_dynamic_layers_v1(u,current_date,current_date+40)d),
  'ladder229',(SELECT jsonb_agg(to_jsonb(d)ORDER BY flow_date)FROM public.lts_dashboard_cash_ladder_from_flow_v229(u,current_date,current_date+40,f)d),
  'ladder2',(SELECT jsonb_agg(to_jsonb(d)ORDER BY flow_date)FROM public.lts_dashboard_cash_ladder_from_flow_v2(u,current_date,current_date+40,f)d),
  'overlay',public.lts_flow_morgan_available_overlay_v1(u,jsonb_build_object('current_future',f)),
  'scenarios1',public.lts_cashflow_scenarios_v1(u,current_date,current_date+40),
  'scenarios2',public.lts_cashflow_scenarios_v2(u,current_date,current_date+40),
  'scenarios_flow',public.lts_cashflow_scenarios_from_flow_v1(u,current_date,current_date+40,f),
  'executive',public.lts_dashboard_executive_v2(u,current_date+40));
 RETURN r;
END$$;
