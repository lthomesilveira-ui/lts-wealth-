BEGIN;
CREATE FUNCTION public.qa_forward_reference_v399(p_days jsonb,p_from date,p_to date)RETURNS jsonb LANGUAGE sql AS $$
WITH all_src AS(SELECT x,(x->>'date')::date dt FROM jsonb_array_elements(p_days)x WHERE(x->>'date')::date BETWEEN p_from AND p_to+30),adj AS(
 SELECT s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',coalesce(to_jsonb(CASE WHEN(SELECT count(*)=30 AND count(DISTINCT y.dt)=30 AND count(nullif(y.x#>>'{Consolidado,economic_net}',''))=30 FROM all_src y WHERE y.dt>s.dt AND y.dt<=s.dt+30)
 THEN nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric+(SELECT sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric)FROM all_src y WHERE y.dt>s.dt AND y.dt<=s.dt+30)ELSE NULL END),'null'),true)x FROM all_src s WHERE dt<=p_to)
SELECT coalesce(jsonb_agg(x ORDER BY dt),'[]')FROM adj;
$$;
DO $test$
DECLARE source jsonb;variant jsonb;a jsonb;b jsonb;n integer;
BEGIN
 SELECT jsonb_agg(jsonb_build_object('date',date '2030-01-01'+i,'Consolidado',jsonb_build_object('economic_net',CASE WHEN i%2=0 THEN -2 ELSE 3 END),'fix86_columns',jsonb_build_object('liq_d0_1',100,'fgts',500,'rsus_vested',50)))INTO source FROM generate_series(0,95)i;
 FOR n IN 0..4 LOOP
  variant:=source;
  IF n=1 THEN variant:=variant-17;END IF;
  IF n=2 THEN variant:=variant||jsonb_build_array(source->17);END IF;
  IF n=3 THEN variant:=jsonb_set(variant,'{17,Consolidado,economic_net}','null');END IF;
  IF n=4 THEN variant:=jsonb_set(variant,'{0,fix86_columns,liq_d0_1}','null');END IF;
  a:=public.lts_forward_liquidity_days_v399(variant,'2030-01-01','2030-03-01');b:=public.qa_forward_reference_v399(variant,'2030-01-01','2030-03-01');
  IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'forward window differs from original rule, case %',n;END IF;
 END LOOP;
 IF public.lts_forward_liquidity_days_v399('[]','2030-01-01','2030-03-01')<>'[]' THEN RAISE EXCEPTION 'empty source fabricated';END IF;
END $test$;
ROLLBACK;
SELECT 'V399 forward window matches old calculation, missing days, duplicates and unknowns' result;
