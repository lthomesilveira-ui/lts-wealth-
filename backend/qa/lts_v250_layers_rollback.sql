SET LOCAL lock_timeout='1500ms';SET LOCAL statement_timeout='45s';SET LOCAL jit='off';SET LOCAL timezone='America/Sao_Paulo';
CREATE TABLE IF NOT EXISTS public.lts_v250_validation_report(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),report jsonb NOT NULL);
ALTER TABLE public.lts_v250_validation_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v250_validation_report FROM PUBLIC,anon,authenticated,service_role;
DO $qa$ DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); old_hash text; report jsonb; cases jsonb:='[]';r record;a jsonb;b jsonb;t timestamptz;old_ms numeric;new_ms numeric;old_warm_ms numeric;new_warm_ms numeric;BEGIN
 old_hash:=(SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text) ORDER BY p.oid::regprocedure::text)::text) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f');
 BEGIN
 IF md5(btrim(pg_get_functiondef('public.lts_daily_flow_full_query_v5(uuid,date,date)'::regprocedure),E' \t\r\n'))<>'7ffa50a2c170e5c76873deb0f19912e0' THEN RAISE EXCEPTION 'V250_SOURCE_LEASE_CHANGED';END IF;
 EXECUTE 'CREATE OR REPLACE FUNCTION public.lts_daily_flow_full_query_v5_baseline_v250(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
 SET "TimeZone" TO ''America/Sao_Paulo''
AS $function$
declare
  j jsonb; h jsonb:=''[]''::jsonb; x jsonb; d date;
  bank numeric; d0 numeric; rsu numeric; fgts numeric; d01 numeric; total numeric; total_fgts numeric;
  bd0 text; brsu text; bfgts text; c jsonb;
begin
  j:=public.lts_daily_flow_full_query_v4(p_user_id,p_from,p_to);
  if p_to>=current_date then
    j:=jsonb_set(j,''{current_future}'',public.lts_daily_flow_fix86_v12(p_user_id,greatest(p_from,current_date),p_to),true);
  end if;
  for x in select value from jsonb_array_elements(coalesce(j#>''{historical,days}'',''[]''::jsonb)) order by value->>''date'' loop
    d:=(x->>''date'')::date;
    if d>=date ''2026-07-07'' and nullif(x#>>''{Consolidado,bank_balance}'','''') is not null then
      select q.d0_resource,q.rsu_vested,q.d0_basis,q.rsu_basis into d0,rsu,bd0,brsu
      from public.lts_historical_liquidity_layers_v1(p_user_id,d,d) q limit 1;
      select q.fgts_value,q.fgts_basis into fgts,bfgts
      from public.lts_historical_fgts_layer_v1(p_user_id,d,d) q limit 1;
      bank:=(x#>>''{Consolidado,bank_balance}'')::numeric;
      d01:=case when d0 is null then null else bank+d0 end;
      total:=case when d01 is null then null else d01+coalesce(rsu,0) end;
      total_fgts:=case when total is null then null else total+coalesce(fgts,0) end;
      c:=coalesce(x->''fix86_columns'',''{}''::jsonb)||jsonb_build_object(
        ''saldo_final'',bank,''liq_d0_1_recurso'',d0,''liq_d0_1'',d01,''saldo_apos_d0_1'',d01,
        ''rsus_vested'',rsu,''saldo_apos_rsu'',total,''disponivel_total'',total,''posicao_curto_prazo'',total,
        ''fgts'',fgts,''saldo_apos_fgts'',total_fgts,''historical_d0_basis'',bd0,''historical_rsu_basis'',brsu,
        ''historical_fgts_basis'',bfgts,''basis'',''unified_historical_cash_ladder_reconstructed_from_evidence'');
      x:=jsonb_set(x,''{fix86_columns}'',c,true);
    end if;
    h:=h||jsonb_build_array(x);
  end loop;
  j:=jsonb_set(j,''{historical,days}'',h,true);
  return j || jsonb_build_object(
    ''version'',''daily-flow-full-query-v5-unified-layers-current-day-v12'',
    ''liquidity_history_contract'',jsonb_build_object(''d0_rsu_from'',''2026-07-07'',''fgts_recent_from'',''2026-07-21'',''historical_excel_recovery_before_recent_anchors'',''blocked_without_exact_values'',''period_queries_same_financial_layers_as_initial_view'',true,''current_day_documentary_facts'',true,''semantic_context_pairs'',true)
  );
end $function$;';
 REVOKE ALL ON FUNCTION public.lts_daily_flow_full_query_v5_baseline_v250(uuid,date,date) FROM PUBLIC,anon,authenticated,service_role;
 EXECUTE 'CREATE OR REPLACE FUNCTION public.lts_daily_flow_full_query_v5(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
 SET "TimeZone" TO ''America/Sao_Paulo''
AS $function$
declare
  j jsonb; h jsonb:=''[]''::jsonb; output_rows jsonb[]:=ARRAY[]::jsonb[]; layers jsonb; layer_row jsonb; lo date; hi date; x jsonb; d date;
  bank numeric; d0 numeric; rsu numeric; fgts numeric; d01 numeric; total numeric; total_fgts numeric;
  bd0 text; brsu text; bfgts text; c jsonb;
begin
  j:=public.lts_daily_flow_full_query_v4(p_user_id,p_from,p_to);
  if p_to>=current_date then
    j:=jsonb_set(j,''{current_future}'',public.lts_daily_flow_fix86_v12(p_user_id,greatest(p_from,current_date),p_to),true);
  end if;
  SELECT min((day->>''date'')::date),max((day->>''date'')::date) INTO lo,hi
  FROM jsonb_array_elements(coalesce(j#>''{historical,days}'',''[]''))day
  WHERE (day->>''date'')::date>=date ''2026-07-07'' AND nullif(day#>>''{Consolidado,bank_balance}'','''') IS NOT NULL;
  IF lo IS NOT NULL THEN
    SELECT jsonb_object_agg(q.flow_date::text,to_jsonb(q)||to_jsonb(g)) INTO layers
    FROM public.lts_historical_liquidity_layers_v1(p_user_id,lo,hi) q
    JOIN public.lts_historical_fgts_layer_v1(p_user_id,lo,hi) g USING(flow_date);
  END IF;
  for x in select value from jsonb_array_elements(coalesce(j#>''{historical,days}'',''[]''::jsonb)) order by value->>''date'' loop
    d:=(x->>''date'')::date;
    if d>=date ''2026-07-07'' and nullif(x#>>''{Consolidado,bank_balance}'','''') is not null then
      layer_row:=layers->d::text;
      IF layer_row IS NULL THEN RAISE EXCEPTION ''V250_DATED_LAYER_COVERAGE_INCOMPLETE'';END IF;
      d0:=(layer_row->>''d0_resource'')::numeric;rsu:=(layer_row->>''rsu_vested'')::numeric;
      bd0:=layer_row->>''d0_basis'';brsu:=layer_row->>''rsu_basis'';
      fgts:=(layer_row->>''fgts_value'')::numeric;bfgts:=layer_row->>''fgts_basis'';
      bank:=(x#>>''{Consolidado,bank_balance}'')::numeric;
      d01:=case when d0 is null then null else bank+d0 end;
      total:=case when d01 is null then null else d01+coalesce(rsu,0) end;
      total_fgts:=case when total is null then null else total+coalesce(fgts,0) end;
      c:=coalesce(x->''fix86_columns'',''{}''::jsonb)||jsonb_build_object(
        ''saldo_final'',bank,''liq_d0_1_recurso'',d0,''liq_d0_1'',d01,''saldo_apos_d0_1'',d01,
        ''rsus_vested'',rsu,''saldo_apos_rsu'',total,''disponivel_total'',total,''posicao_curto_prazo'',total,
        ''fgts'',fgts,''saldo_apos_fgts'',total_fgts,''historical_d0_basis'',bd0,''historical_rsu_basis'',brsu,
        ''historical_fgts_basis'',bfgts,''basis'',''unified_historical_cash_ladder_reconstructed_from_evidence'');
      x:=jsonb_set(x,''{fix86_columns}'',c,true);
    end if;
    output_rows:=array_append(output_rows,x);
  end loop;
  h:=to_jsonb(output_rows);
  j:=jsonb_set(j,''{historical,days}'',h,true);
  return j || jsonb_build_object(
    ''version'',''daily-flow-full-query-v5-unified-layers-current-day-v12'',
    ''liquidity_history_contract'',jsonb_build_object(''d0_rsu_from'',''2026-07-07'',''fgts_recent_from'',''2026-07-21'',''historical_excel_recovery_before_recent_anchors'',''blocked_without_exact_values'',''period_queries_same_financial_layers_as_initial_view'',true,''current_day_documentary_facts'',true,''semantic_context_pairs'',true)
  );
end $function$;
';
 FOR r IN SELECT * FROM(VALUES(date '2026-01-01',date '2027-12-31'),(date '2026-07-06',date '2026-07-22'),(date '2019-01-01',date '2020-12-31'))v(start_day,end_day) LOOP
 t:=clock_timestamp();a:=public.lts_daily_flow_full_query_v5_baseline_v250(u,r.start_day,r.end_day);old_ms:=round(extract(epoch FROM(clock_timestamp()-t))*1000,1);
 t:=clock_timestamp();b:=public.lts_daily_flow_full_query_v5(u,r.start_day,r.end_day);new_ms:=round(extract(epoch FROM(clock_timestamp()-t))*1000,1);
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'V250 full payload parity failed';END IF;
 t:=clock_timestamp();IF a IS DISTINCT FROM public.lts_daily_flow_full_query_v5_baseline_v250(u,r.start_day,r.end_day) THEN RAISE EXCEPTION 'baseline replay changed';END IF;old_warm_ms:=round(extract(epoch FROM(clock_timestamp()-t))*1000,1);
 t:=clock_timestamp();IF a IS DISTINCT FROM public.lts_daily_flow_full_query_v5(u,r.start_day,r.end_day) THEN RAISE EXCEPTION 'candidate replay changed';END IF;new_warm_ms:=round(extract(epoch FROM(clock_timestamp()-t))*1000,1);
 cases:=cases||jsonb_build_array(jsonb_build_object('from',r.start_day,'to',r.end_day,'baseline_ms',old_ms,'candidate_ms',new_ms,'baseline_warm_ms',old_warm_ms,'candidate_warm_ms',new_warm_ms,'exact_full_json_parity',true,'historical_days',jsonb_array_length(a#>'{historical,days}'),'future_days',jsonb_array_length(a#>'{current_future,days}')));
 END LOOP;
 report:=jsonb_build_object('status','PASS','cases',cases);
 RAISE EXCEPTION USING ERRCODE='P2500',MESSAGE='rollback V250 candidate DDL and caches';
 EXCEPTION WHEN SQLSTATE 'P2500' THEN NULL;
 WHEN query_canceled THEN report:=jsonb_build_object('status','FAIL','error',SQLERRM,'sqlstate',SQLSTATE);
 WHEN OTHERS THEN report:=jsonb_build_object('status','FAIL','error',SQLERRM,'sqlstate',SQLSTATE);
 END;
 IF old_hash IS DISTINCT FROM (SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text) ORDER BY p.oid::regprocedure::text)::text) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f') OR to_regprocedure('public.lts_daily_flow_full_query_v5_baseline_v250(uuid,date,date)') IS NOT NULL THEN RAISE EXCEPTION 'V250 rollback incomplete';END IF;
 INSERT INTO public.lts_v250_validation_report(report) VALUES(report||jsonb_build_object('candidate_ddl_and_cache_writes_rolled_back',true,'function_definitions_and_acls_restored',true));
END $qa$;
