-- Read-only scenario correction. No bank fact, asset position, or user configuration is changed.
CREATE OR REPLACE FUNCTION public.lts_flow_configured_fgts_v240(p_user_id uuid,p_flow jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
DECLARE cfg record; credits jsonb; days jsonb; enabled boolean; monthly numeric;
BEGIN
 SELECT count(*) FILTER(WHERE dados->>'_k'='salario_base')=1
   AND count(*) FILTER(WHERE dados->>'_k'='percentual')=1
   AND count(*) FILTER(WHERE dados->>'_k'='ativo')=1 valid,
  max((dados->>'_v')::numeric) FILTER(WHERE dados->>'_k'='salario_base') salary,
  max((dados->>'_v')::numeric) FILTER(WHERE dados->>'_k'='percentual') pct,
  bool_or((dados->>'_v')::boolean) FILTER(WHERE dados->>'_k'='ativo') active,
  max((dados->>'_v')::date) FILTER(WHERE dados->>'_k'='data_inicio') starts
 INTO cfg FROM public.fgts WHERE usuario_id=p_user_id;
 enabled:=coalesce(cfg.valid AND cfg.active AND cfg.salary>=0 AND cfg.pct>=0 AND cfg.pct<=1,false);
 monthly:=CASE WHEN enabled THEN round(cfg.salary*cfg.pct,2) ELSE 0 END;
 -- One scheduled contribution per regular-payroll month, never an advance or 13th salary.
 SELECT coalesce(jsonb_agg(dt ORDER BY dt),'[]') INTO credits FROM (
  SELECT min((e->>'event_date')::date) dt
  FROM jsonb_array_elements(coalesce(p_flow#>'{current_future,events}','[]')) e
  WHERE (e->>'event_date')::date>p_as_of
    AND (e->>'event_date')::date>=coalesce(cfg.starts,p_as_of)
    AND (e->>'signed_amount')::numeric>0 AND NOT coalesce((e->>'displaced')::boolean,false)
    AND (e->>'semantic_rule_id'='sys_salario_liquido_exact'
      OR lower(trim(e->>'description')) IN ('salário','salário líquido'))
  GROUP BY left(e->>'event_date',7)
 ) s;
 SELECT coalesce(jsonb_agg(d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
   'fgts_documental',(c->>'fgts')::numeric,
   'saldo_apos_fgts_documental',(c->>'saldo_apos_fgts')::numeric,
   'fgts_aportes_projetados',accrual,'fgts',(c->>'fgts')::numeric+accrual,
   'saldo_apos_fgts',(c->>'saldo_apos_fgts')::numeric+accrual,
   'fgts_projection_basis',CASE WHEN enabled THEN 'configured_future_payroll_not_received' ELSE 'documented_only' END
  )) ORDER BY d->>'date'),'[]') INTO days
 FROM jsonb_array_elements(coalesce(p_flow#>'{current_future,days}','[]')) d
 CROSS JOIN LATERAL (SELECT d->'fix86_columns' c) cols
 CROSS JOIN LATERAL (SELECT monthly*(SELECT count(*) FROM jsonb_array_elements_text(credits) t WHERE t.value::date<=(d->>'date')::date) accrual) a;
 RETURN jsonb_set(p_flow,'{current_future,days}',days)||jsonb_build_object('fgts_projection_contract',jsonb_build_object(
  'version','configured-future-fgts-v240','as_of',p_as_of,'enabled',enabled,'configuration_valid',cfg.valid,
  'monthly_estimate_brl',monthly,'salary_base_brl',cfg.salary,'percentage',cfg.pct,'credit_dates',credits,
  'basis','Documented position plus configured contributions on future regular payroll dates; no catch-up deposit assumed.',
  'restriction','Conditional restricted resource, not bank cash; contribution dates and receipt are estimates.'
 ));
END $function$;
REVOKE ALL ON FUNCTION public.lts_flow_configured_fgts_v240(uuid,jsonb,date) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_v240(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; f jsonb; part text; d jsonb; c jsonb; historical_days jsonb:='[]'; bank text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 -- Include the anchor and preceding future payroll in every slice so the scenario is range independent.
 j:=public.lts_browser_flow_v229(least(p_from,current_date),p_to);
 f:=public.lts_flow_configured_fgts_v240(u,j->'flow',current_date);
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(day_row ORDER BY day_row->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]'))day_row WHERE (day_row->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(e ORDER BY e->>'event_date',e->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]'))e WHERE (e->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 -- An unanchored cumulative ledger is not an absolute bank position.
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP
  IF coalesce((d->>'relative_balance_display')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_certified')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_reconstructed')::boolean,false) THEN
   c:=d->'fix86_columns';
   d:=d||jsonb_build_object('relative_position_debug',jsonb_build_object('legacy_columns',c,'legacy_consolidated',d->'Consolidado'),
    'absolute_position_status','unknown_source_conflict_or_missing_anchor',
    'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',NULL),
    'fix86_columns',c||jsonb_build_object('saldo_anterior',NULL,'saldo_final',NULL,'saldo_anterior_operacional',NULL,'saldo_final_operacional',NULL));
   FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    IF d#>>ARRAY[bank,'balance_basis']='relative_tracked_bank_ledger' THEN
     d:=jsonb_set(d,ARRAY[bank],(d->bank)||jsonb_build_object('balance',NULL,'opening_balance',NULL));
    END IF;
   END LOOP;
  END IF;
  historical_days:=historical_days||jsonb_build_array(d);
 END LOOP;
 f:=jsonb_set(f,'{historical,days}',historical_days)||jsonb_build_object('from',p_from,'to',p_to);
 RETURN j||jsonb_build_object('flow',f,'reader_revision','v240-configured-and-documentary-fgts-scenarios');
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v240(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v240(date,date) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v240()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; result jsonb; last_day date:=make_date(extract(year FROM current_date)::int+1,12,31);
BEGIN
 j:=public.lts_browser_flow_v240(current_date,last_day);
 WITH d AS (SELECT x->>'date' dt,x->'fix86_columns' c FROM jsonb_array_elements(j#>'{flow,current_future,days}')x),
 s AS (SELECT min(dt) FILTER(WHERE (c->>'saldo_apos_d0_1')::numeric<0) d01,
  min(dt) FILTER(WHERE (c->>'saldo_apos_rsu')::numeric<0) rsu,
  min(dt) FILTER(WHERE (c->>'saldo_apos_fgts')::numeric<0) fg,
  min(dt) FILTER(WHERE (c->>'saldo_apos_fgts_documental')::numeric<0) doc,
  min((c->>'saldo_apos_fgts')::numeric) fg_min,min((c->>'saldo_apos_fgts_documental')::numeric) doc_min FROM d)
 SELECT jsonb_build_object('version','planning-ui-contract-v2','scenario_revision','v240','period_to',last_day,
  'd01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',fg IS NULL,
  'fgts_documented_first_negative',doc,'fgts_projected_minimum',fg_min,'fgts_documented_minimum',doc_min,
  'fgts_projection_contract',j#>'{flow,fgts_projection_contract}',
  'labels',jsonb_build_object(
   'd01',CASE WHEN d01 IS NULL THEN 'Caixa consolidado após D0/D1 preservado até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') END,
   'rsu',CASE WHEN rsu IS NULL THEN 'Com RSUs atuais e vestings programados, sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Com RSUs atuais e vestings programados, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') END,
   'fgts','Com FGTS '||CASE WHEN coalesce((j#>>'{flow,fgts_projection_contract,enabled}')::boolean,false) THEN 'projetado' ELSE 'documental' END||CASE WHEN fg IS NULL THEN ', sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE ', a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') END)) INTO result FROM s;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_planning_ui_contract_v240() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_planning_ui_contract_v240() TO authenticated,service_role;
