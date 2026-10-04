-- Honor the owner's September decision. A stale active configuration is not approval.
-- Pure read transformation; no facts, positions, configurations or prior releases are changed.
CREATE OR REPLACE FUNCTION public.lts_flow_fgts_owner_policy_v241(p_flow jsonb,p_as_of date)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
 SELECT jsonb_set(p_flow,'{current_future,days}',coalesce((
  SELECT jsonb_agg(d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
   'fgts',coalesce(c->'fgts_documental',c->'fgts'),
   'fgts_documental',coalesce(c->'fgts_documental',c->'fgts'),
   'fgts_aportes_projetados',0,
   'saldo_apos_fgts',coalesce(c->'saldo_apos_fgts_documental',c->'saldo_apos_fgts'),
   'saldo_apos_fgts_documental',coalesce(c->'saldo_apos_fgts_documental',c->'saldo_apos_fgts'),
   'fgts_projection_basis','documented_only_owner_policy'
  )) ORDER BY d->>'date')
  FROM jsonb_array_elements(coalesce(p_flow#>'{current_future,days}','[]'))d
  CROSS JOIN LATERAL (SELECT d->'fix86_columns' c)columns
 ),'[]'))||jsonb_build_object('fgts_projection_contract',jsonb_build_object(
  'version','documentary-owner-fgts-v241','as_of',p_as_of,'enabled',false,
  'owner_policy','documented_only_no_new_contributions',
  'owner_decision_ref','LTS_OWNER_DECISION_FGTS_DOCUMENTARY_20260904',
  'policy_confirmed_on','2026-09-04','legacy_configuration_authorizes_projection',false,
  'monthly_estimate_brl',0,'credit_dates','[]'::jsonb,
  'contingency_access_days_informed_by_owner',30,
  'basis','Documented FGTS only. Owner decision overrides stale active legacy configuration.',
  'restriction','Restricted contingency, approximately D+30 if requested and available; not immediate bank cash or an executed withdrawal.'
 ));
$function$;
REVOKE ALL ON FUNCTION public.lts_flow_fgts_owner_policy_v241(jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_fgts_owner_policy_v241(jsonb,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_v241(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb;
BEGIN
 j:=public.lts_browser_flow_v240(p_from,p_to);
 RETURN j||jsonb_build_object('flow',public.lts_flow_fgts_owner_policy_v241(j->'flow',current_date),
  'reader_revision','v241-documentary-fgts-owner-policy');
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v241(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v241(date,date) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v241()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; result jsonb; last_day date:=make_date(extract(year FROM current_date)::int+1,12,31);
BEGIN
 j:=public.lts_browser_flow_v241(current_date,last_day);
 WITH d AS (SELECT x->>'date' dt,x->'fix86_columns' c FROM jsonb_array_elements(j#>'{flow,current_future,days}')x),
 s AS (SELECT min(dt) FILTER(WHERE (c->>'saldo_apos_d0_1')::numeric<0) d01,
  min(dt) FILTER(WHERE (c->>'saldo_apos_rsu')::numeric<0) rsu,
  min(dt) FILTER(WHERE (c->>'saldo_apos_fgts')::numeric<0) fg,
  min((c->>'saldo_apos_fgts')::numeric) fg_min FROM d)
 SELECT jsonb_build_object('version','planning-ui-contract-v2','scenario_revision','v241','period_to',last_day,
  'd01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',fg IS NULL,
  'fgts_documented_first_negative',fg,'fgts_documented_minimum',fg_min,
  'fgts_projection_contract',j#>'{flow,fgts_projection_contract}',
  'labels',jsonb_build_object(
   'd01',CASE WHEN d01 IS NULL THEN 'Caixa consolidado após D0/D1 preservado até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') END,
   'rsu',CASE WHEN rsu IS NULL THEN 'Com RSUs atuais e vestings programados, sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Com RSUs atuais e vestings programados, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') END,
   'fgts','Com FGTS documental'||CASE WHEN fg IS NULL THEN ', sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE ', a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') END)) INTO result FROM s;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_planning_ui_contract_v241() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_planning_ui_contract_v241() TO authenticated,service_role;
