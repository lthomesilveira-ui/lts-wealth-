-- V411: owner-scoped conservative RSU liquidity. Source positions and dates survive.
-- The private owner namespace is seeded separately with source hashes and an audit.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION lts_award_private.owner_policy_v411(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE p jsonb; r numeric; n numeric;
BEGIN
 SELECT nullif(valor_bruto,'')::jsonb INTO p FROM public.legacy_namespace
 WHERE usuario_id=p_user_id AND chave='lts_owner_rsu_policy_v411';
 IF NOT FOUND THEN RETURN '{}'::jsonb; END IF;
 IF p IS NULL THEN RAISE EXCEPTION 'Política de RSU existente sem conteúdo válido.'; END IF;
 IF jsonb_typeof(p)<>'object' OR p->>'schema_version' IS DISTINCT FROM '1'
  OR jsonb_typeof(p->'policy')<>'object'
  OR NOT coalesce(p#>'{policy,scope}' @> '["RSU","Cash RSU"]'::jsonb,false)
  OR coalesce(nullif(p#>>'{policy,approved_at}',''),nullif(p#>>'{policy,approved_on}','')) IS NULL
 THEN RAISE EXCEPTION 'Política de RSU incompleta.'; END IF;
 r:=nullif(p#>>'{policy,reserve_rate}','')::numeric;
 n:=nullif(p#>>'{policy,net_factor}','')::numeric;
 IF r IS NULL OR n IS NULL OR r<0 OR r>1 OR n<>1-r THEN
  RAISE EXCEPTION 'Reserva de RSU inconsistente.';
 END IF;
 RETURN p;
END $f$;

CREATE OR REPLACE FUNCTION lts_award_private.net_value_v411(
 p_user_id uuid,p_asset_type text,p_gross numeric,p_previous_net numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE p jsonb:=lts_award_private.owner_policy_v411(p_user_id);
BEGIN
 IF p ? 'policy' AND (upper(trim(p_asset_type))='RSU' OR lower(p_asset_type) LIKE '%cash%') THEN
  IF p_gross IS NULL OR p_gross<0 THEN RAISE EXCEPTION 'Componente de RSU sem valor bruto válido.'; END IF;
  RETURN round(p_gross*(p#>>'{policy,net_factor}')::numeric,2);
 END IF;
 RETURN coalesce(p_previous_net,p_gross);
END $f$;

CREATE OR REPLACE FUNCTION lts_award_private.considered_value_v411(
 p_user_id uuid,p_asset_type text,p_gross numeric,p_net numeric,p_previous numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF (upper(trim(p_asset_type))='RSU' OR lower(p_asset_type) LIKE '%cash%')
  AND lts_award_private.owner_policy_v411(p_user_id) ? 'policy' THEN
  IF p_gross IS NULL OR p_net IS NULL THEN RAISE EXCEPTION 'Componente de RSU incompleto.'; END IF;
  RETURN p_net;
 END IF;
 RETURN p_previous;
END $f$;

CREATE OR REPLACE FUNCTION lts_award_private.grant_eligibility_v411(
 p_user_id uuid,p_metadata jsonb,p_asset_type text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE p jsonb:=lts_award_private.owner_policy_v411(p_user_id); g jsonb; d date; n integer;
BEGIN
 IF NOT (p ? 'policy') OR p_metadata->>'grant_date_basis' IS DISTINCT FROM 'documentary'
  OR coalesce(jsonb_typeof(p_metadata->'grant_source_document_ids'),'null')<>'array'
  OR jsonb_array_length(p_metadata->'grant_source_document_ids')=0
  OR nullif(p_metadata->>'grant_id','') IS NULL OR nullif(p_metadata->>'grant_date','') IS NULL
 THEN RETURN NULL; END IF;
 d:=(p_metadata->>'grant_date')::date;
 SELECT count(*),min(value::text)::jsonb INTO n,g
 FROM jsonb_array_elements(coalesce(p#>'{acceleration,grants}','[]'::jsonb))
 WHERE value->>'grant_id'=p_metadata->>'grant_id'
  AND (value->>'grant_date')::date=d
  AND (CASE WHEN lower(value->>'asset_type') LIKE '%cash%' THEN 'cash' ELSE upper(value->>'asset_type') END)
      =(CASE WHEN lower(p_asset_type) LIKE '%cash%' THEN 'cash' ELSE upper(p_asset_type) END);
 IF n<>1 THEN RETURN NULL; END IF;
 RETURN d<date '2026-01-01';
END $f$;

REVOKE ALL ON FUNCTION lts_award_private.owner_policy_v411(uuid),
 lts_award_private.net_value_v411(uuid,text,numeric,numeric),
 lts_award_private.considered_value_v411(uuid,text,numeric,numeric,numeric),
 lts_award_private.grant_eligibility_v411(uuid,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_award_private TO service_role;
GRANT EXECUTE ON FUNCTION lts_award_private.owner_policy_v411(uuid),
 lts_award_private.net_value_v411(uuid,text,numeric,numeric),
 lts_award_private.considered_value_v411(uuid,text,numeric,numeric,numeric),
 lts_award_private.grant_eligibility_v411(uuid,jsonb,text) TO service_role;

-- Retain the existing valuation stage and output row type. The owner reserve is
-- applied exactly once to rounded gross, including manual and unavailable quotes.
CREATE OR REPLACE VIEW public.lts_future_liquidity_effective_v290 WITH(security_invoker=true) AS
WITH quotes AS MATERIALIZED(SELECT public.lts_market_context_v290() context)
SELECT s.id,s.user_id,s.source_asset_id,s.asset_type,s.institution,s.eligibility_date,
 s.settlement_days,s.quantity,result.unit_price_assumption,result.fx_assumption,
 result.gross_value_brl,result.net_value_brl,result.tax_status,s.cash_treatment,
 s.confidence,s.source,result.metadata,s.active,s.created_at,s.updated_at
FROM public.lts_future_liquidity_schedule s
CROSS JOIN quotes q LEFT JOIN public.app_settings a ON a.user_id=s.user_id
CROSS JOIN LATERAL jsonb_populate_record(NULL::public.lts_future_liquidity_schedule,to_jsonb(s)||CASE
 WHEN s.active AND s.eligibility_date>=(now() AT TIME ZONE 'America/Sao_Paulo')::date
 AND (upper(trim(s.asset_type))='RSU' OR lower(s.asset_type) LIKE '%cash%')
 AND q.context->>'complete'='true' AND coalesce(a.settings->>'market_quote_mode','automatic')='automatic'
 THEN jsonb_build_object('unit_price_assumption',(q.context#>>'{stock,value}')::numeric,
  'fx_assumption',(q.context#>>'{usd_brl,value}')::numeric,
  'gross_value_brl',round(s.quantity*(q.context#>>'{stock,value}')::numeric*(q.context#>>'{usd_brl,value}')::numeric,2),
  'net_value_brl',round(s.quantity*(q.context#>>'{stock,value}')::numeric*(q.context#>>'{usd_brl,value}')::numeric*
   CASE WHEN lower(s.asset_type) LIKE '%cash%' THEN 0.70 ELSE 1 END,2),
  'metadata',coalesce(s.metadata,'{}')||jsonb_build_object('valuation_basis','automatic_market_reference','market_quotes',q.context))
 ELSE '{}'::jsonb END) priced
CROSS JOIN LATERAL (SELECT lts_award_private.owner_policy_v411(s.user_id) p) policy
CROSS JOIN LATERAL jsonb_populate_record(NULL::public.lts_future_liquidity_schedule,to_jsonb(priced)||CASE
 WHEN policy.p ? 'policy' AND s.active AND (upper(trim(s.asset_type))='RSU' OR lower(s.asset_type) LIKE '%cash%')
 THEN jsonb_build_object(
  'net_value_brl',lts_award_private.net_value_v411(s.user_id,s.asset_type,priced.gross_value_brl,priced.net_value_brl),
  'tax_status','owner_conservative_net_estimate',
  'metadata',coalesce(priced.metadata,'{}')||jsonb_build_object('cash_policy_v411',jsonb_build_object(
    'reserve_rate',(policy.p#>>'{policy,reserve_rate}')::numeric,
    'net_factor',(policy.p#>>'{policy,net_factor}')::numeric,
    'basis','owner_confirmed_conservative_cash_reserve','applied_once',true)))
 ELSE '{}'::jsonb END) result;
REVOKE ALL ON public.lts_future_liquidity_effective_v290 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_future_liquidity_effective_v290 TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_rsu_policy_v411()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); p jsonb:=lts_award_private.owner_policy_v411(u);
 enabled boolean:=p ? 'policy'; factor numeric; rate numeric; summary jsonb; schedule jsonb;
 ref jsonb; acceleration jsonb; grants jsonb; fx numeric; price numeric;
 regular_net numeric; reference_cash_net numeric; eligible_quantity numeric; excluded_quantity numeric;
 mapped integer; unmapped integer; grant_count integer; unique_grants integer; bad_grants integer;
BEGIN
 IF NOT enabled THEN
  RETURN jsonb_build_object('schema_version',1,'version','rsu-policy-v411',
   'policy',jsonb_build_object('enabled',false,'basis','legacy_policy_preserved'),
   'summary',NULL,'future_schedule','[]'::jsonb,'morgan_reference',NULL,
   'acceleration',NULL,'payroll_policy',NULL);
 END IF;
 factor:=CASE WHEN enabled THEN (p#>>'{policy,net_factor}')::numeric END;
 rate:=CASE WHEN enabled THEN (p#>>'{policy,reserve_rate}')::numeric END;
 WITH rows AS MATERIALIZED (
  SELECT s.*,coalesce(s.net_value_brl,s.gross_value_brl) cash_net,
   lts_award_private.grant_eligibility_v411(u,s.metadata,s.asset_type) eligible,
   CASE WHEN lower(s.asset_type) LIKE '%cash%' THEN 'Cash RSU' ELSE 'RSU' END kind
  FROM public.lts_future_liquidity_effective_v290 s WHERE s.user_id=u AND s.active
  AND (upper(trim(s.asset_type))='RSU' OR lower(s.asset_type) LIKE '%cash%')
 ), grouped AS (
  SELECT kind,eligibility_date,max(eligibility_date+settlement_days) available_date,
   sum(quantity) quantity,sum(gross_value_brl) gross,sum(cash_net) net,
   CASE WHEN bool_and(eligible IS TRUE) THEN true WHEN bool_or(eligible IS FALSE) THEN false ELSE NULL END eligible,
   jsonb_agg(jsonb_build_object(
    'award_id',id,'quantity',quantity,'eligibility_date',eligibility_date,
    'available_date',eligibility_date+settlement_days,'gross_value_brl',gross_value_brl,
    'net_value_brl',cash_net,'reserve_value_brl',gross_value_brl-cash_net,
    'grant_id',CASE WHEN eligible IS NOT NULL THEN metadata->>'grant_id' END,
    'grant_date',CASE WHEN eligible IS NOT NULL THEN metadata->>'grant_date' END,
    'grant_year',CASE WHEN eligible IS NOT NULL THEN extract(year FROM (metadata->>'grant_date')::date)::integer END,
    'grant_link_status',CASE WHEN eligible IS NULL THEN 'unmapped' ELSE 'documented' END,
    'acceleration_eligible',eligible,'valuation_basis',coalesce(metadata->>'valuation_basis',source),
    'settlement_days',settlement_days) ORDER BY id) components
  FROM rows GROUP BY kind,eligibility_date
 )
 SELECT jsonb_build_object(
  'schedule_gross_brl',coalesce(sum(gross),0),'schedule_net_brl',coalesce(sum(net),0),
  'schedule_reserve_brl',coalesce(sum(gross-net),0),
  'regular_gross_brl',coalesce(sum(gross) FILTER(WHERE kind='RSU'),0),
  'regular_net_brl',coalesce(sum(net) FILTER(WHERE kind='RSU'),0),
  'cash_gross_brl',coalesce(sum(gross) FILTER(WHERE kind='Cash RSU'),0),
  'cash_net_brl',coalesce(sum(net) FILTER(WHERE kind='Cash RSU'),0),
  'calculation_basis','sum_of_rounded_schedule_components'),
  coalesce(jsonb_agg(jsonb_build_object(
   'group_key',(CASE WHEN kind='Cash RSU' THEN 'cash_rsu:' ELSE 'rsu:' END)||eligibility_date::text,
   'asset_type',kind,'eligibility_date',eligibility_date,'available_date',available_date,
   'quantity',quantity,'gross_value_brl',gross,'net_value_brl',net,'reserve_value_brl',gross-net,
   'acceleration_eligible',eligible,'components',components) ORDER BY eligibility_date,kind),'[]'::jsonb)
 INTO summary,schedule FROM grouped;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(schedule) g WHERE g->'gross_value_brl'='null'::jsonb OR g->'net_value_brl'='null'::jsonb) THEN
  RAISE EXCEPTION 'Há valores de RSU sem base para estimativa.';
 END IF;

 ref:=p->'morgan_reference';
 IF ref IS NOT NULL AND ref<>'null'::jsonb THEN
  IF jsonb_typeof(ref)<>'object' OR ref->>'currency'<>'BRL'
   OR nullif(ref->>'total_gross_brl','') IS NULL OR nullif(ref->>'regular_rsu_gross_brl','') IS NULL
   OR nullif(ref->>'cash_rsu_gross_brl','') IS NULL OR nullif(ref->>'brokerage_cash_brl','') IS NULL
   OR nullif(ref->>'unallocated_gross_brl','') IS NULL
   OR abs((ref->>'total_gross_brl')::numeric-(ref->>'regular_rsu_gross_brl')::numeric
     -(ref->>'cash_rsu_gross_brl')::numeric-(ref->>'brokerage_cash_brl')::numeric
     -(ref->>'unallocated_gross_brl')::numeric)>0.01 THEN
   RAISE EXCEPTION 'A referência Morgan não reconcilia os componentes.';
  END IF;
  regular_net:=round((ref->>'regular_rsu_gross_brl')::numeric*factor,2);
  reference_cash_net:=round((ref->>'cash_rsu_gross_brl')::numeric*factor,2);
  ref:=ref||jsonb_build_object('reference_date_known',nullif(ref->>'as_of_date','') IS NOT NULL,
   'regular_rsu_net_brl',regular_net,'cash_rsu_net_brl',reference_cash_net,
   'known_awards_gross_brl',(ref->>'regular_rsu_gross_brl')::numeric+(ref->>'cash_rsu_gross_brl')::numeric,
   'known_awards_net_brl',regular_net+reference_cash_net,
   'known_after_reserve_brl',regular_net+reference_cash_net+(ref->>'brokerage_cash_brl')::numeric,
   'unallocated_net_brl',NULL,'replaces_dated_position',false);
 ELSE ref:=NULL; END IF;

 acceleration:=p->'acceleration';
 IF acceleration IS NOT NULL AND acceleration<>'null'::jsonb THEN
  IF acceleration->>'status' IS DISTINCT FROM 'conditional' OR nullif(acceleration->>'confirmed_date','') IS NOT NULL
   OR acceleration->>'pre_2026_only' IS DISTINCT FROM 'true' OR jsonb_typeof(acceleration->'grants')<>'array' THEN
   RAISE EXCEPTION 'A antecipação requer revisão documental antes de mudar o calendário.';
  END IF;
  price:=nullif(acceleration->>'price_usd','')::numeric;
  IF price IS NULL OR price<=0 THEN RAISE EXCEPTION 'Valor contratual de antecipação ausente.'; END IF;
  SELECT count(*),count(DISTINCT g->>'grant_id'),count(*) FILTER(WHERE
   nullif(g->>'grant_id','') IS NULL OR nullif(g->>'grant_date','') IS NULL
   OR nullif(g->>'quantity','') IS NULL OR (g->>'quantity')::numeric<0
   OR g->>'asset_type' NOT IN ('RSU','Cash RSU')) INTO grant_count,unique_grants,bad_grants
  FROM jsonb_array_elements(acceleration->'grants')g;
  IF grant_count=0 OR grant_count<>unique_grants OR bad_grants>0 THEN RAISE EXCEPTION 'Concessões incompletas ou duplicadas.'; END IF;
  SELECT coalesce(sum((g->>'quantity')::numeric) FILTER(WHERE (g->>'grant_date')::date<date '2026-01-01'),0),
   coalesce(sum((g->>'quantity')::numeric) FILTER(WHERE (g->>'grant_date')::date>=date '2026-01-01'),0),
   jsonb_agg(g||jsonb_build_object('acceleration_eligible',(g->>'grant_date')::date<date '2026-01-01') ORDER BY g->>'grant_date',g->>'grant_id')
  INTO eligible_quantity,excluded_quantity,grants FROM jsonb_array_elements(acceleration->'grants')g;
  SELECT nullif(public.lts_market_context_v290()#>>'{usd_brl,value}','')::numeric INTO fx;
  IF fx IS NOT NULL AND fx<=0 THEN fx:=NULL; END IF;
  SELECT count(*) FILTER(WHERE c->>'grant_link_status'='documented'),
   count(*) FILTER(WHERE c->>'grant_link_status'<>'documented') INTO mapped,unmapped
  FROM jsonb_array_elements(schedule) g CROSS JOIN LATERAL jsonb_array_elements(g->'components')c;
  acceleration:=acceleration||jsonb_build_object('grant_cutoff','2026-01-01','calendar_unchanged',true,
   'contract_price_usd',price,'eligible_quantity',eligible_quantity,'excluded_quantity',excluded_quantity,
   'eligible_gross_usd',(SELECT coalesce(sum(round((g->>'quantity')::numeric*price,2)),0) FROM jsonb_array_elements(grants)g WHERE (g->>'acceleration_eligible')::boolean),
   'eligible_net_usd',(SELECT coalesce(sum(round((g->>'quantity')::numeric*price*factor,2)),0) FROM jsonb_array_elements(grants)g WHERE (g->>'acceleration_eligible')::boolean),
   'eligible_gross_brl',CASE WHEN fx IS NOT NULL THEN (SELECT coalesce(sum(round((g->>'quantity')::numeric*price*fx,2)),0) FROM jsonb_array_elements(grants)g WHERE (g->>'acceleration_eligible')::boolean) END,
   'eligible_net_brl',CASE WHEN fx IS NOT NULL THEN (SELECT coalesce(sum(round(round((g->>'quantity')::numeric*price*fx,2)*factor,2)),0) FROM jsonb_array_elements(grants)g WHERE (g->>'acceleration_eligible')::boolean) END,
   'fx_rate',fx,'fx_basis',CASE WHEN fx IS NOT NULL THEN 'market_reference' END,
   'schedule_mapped_count',mapped,'schedule_unmapped_count',unmapped,'grants',grants);
 ELSE acceleration:=NULL; END IF;
 RETURN jsonb_build_object('schema_version',1,'version','rsu-policy-v411',
  'policy',jsonb_build_object('enabled',enabled,'reserve_rate',rate,'net_factor',factor,
   'scope',jsonb_build_array('RSU','Cash RSU'),'basis',CASE WHEN enabled THEN 'owner_confirmed_conservative_cash_reserve' ELSE 'legacy_policy_preserved' END,
   'cash_already_available_untouched',true,'retention_award_excluded',true),
  'summary',summary,'future_schedule',schedule,'morgan_reference',ref,'acceleration',acceleration,
  'payroll_policy',CASE WHEN p ? 'payroll' THEN p->'payroll'||jsonb_build_object('forecasts_only',true) END);
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_rsu_policy_v411() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_rsu_policy_v411() TO authenticated,service_role;

-- A hypothetical availability calculation is separate from the conditional
-- corporate transaction estimate above. It never writes dates or events.
CREATE OR REPLACE FUNCTION public.lts_browser_vesting_scenario_v1(p_award_ids text[],p_hypothetical_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); policy jsonb:=lts_award_private.owner_policy_v411(u);
 selected jsonb; source_rows jsonb; cached jsonb; n integer; total numeric; horizon date; flow jsonb;
 base_gap date; scenario_gap date; base_worst numeric; scenario_worst numeric;
BEGIN
 IF p_hypothetical_date IS NULL OR p_hypothetical_date<current_date THEN
  RAISE EXCEPTION 'Informe uma data hipotética de hoje em diante.';
 END IF;
 IF p_award_ids IS NULL OR cardinality(p_award_ids) NOT BETWEEN 1 AND 12
  OR cardinality(p_award_ids)<>(SELECT count(DISTINCT x) FROM unnest(p_award_ids)x) THEN
  RAISE EXCEPTION 'Selecione concessões distintas.';
 END IF;
 IF policy ? 'policy' AND EXISTS(SELECT 1 FROM public.lts_future_liquidity_schedule s
  WHERE s.user_id=u AND s.id=any(p_award_ids)
   AND lts_award_private.grant_eligibility_v411(u,s.metadata,s.asset_type) IS DISTINCT FROM true) THEN
  RAISE EXCEPTION 'O cenário exige vínculo documental a concessões anteriores a 2026.';
 END IF;
 SELECT payload INTO cached FROM public.lts_product_read_cache WHERE user_id=u;
 IF policy ? 'policy' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('available_date',s.eligibility_date+s.settlement_days)),'[]'::jsonb)
  INTO source_rows FROM public.lts_future_liquidity_effective_v290 s WHERE s.user_id=u AND s.active;
 ELSE source_rows:=coalesce(cached#>'{wealth,asset_layers,derived_future_schedule}','[]'::jsonb); END IF;
 WITH rows AS(SELECT s,coalesce(nullif(s->>'net_value_brl','')::numeric,(s->>'gross_value_brl')::numeric) amount
  FROM jsonb_array_elements(source_rows)s WHERE s->>'id'=any(p_award_ids))
 SELECT count(*),sum(amount),jsonb_agg(s||jsonb_build_object('scenario_amount_brl',amount,
  'scenario_basis',CASE WHEN nullif(s->>'net_value_brl','') IS NOT NULL THEN 'net_estimated' ELSE 'gross_only' END)
  ORDER BY s->>'available_date') INTO n,total,selected FROM rows;
 IF n<>cardinality(p_award_ids) THEN RAISE EXCEPTION 'Uma concessão não foi localizada para este titular.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(selected)x WHERE p_hypothetical_date>(x->>'available_date')::date) THEN
  RAISE EXCEPTION 'A data hipotética não pode exceder a disponibilidade original.';
 END IF;
 horizon:=coalesce(nullif(cached#>>'{planning_ladder,to}','')::date,current_date+365);
 flow:=public.lts_daily_flow_fix86_v13(u,current_date,horizon);
 WITH baseline AS MATERIALIZED(SELECT * FROM public.lts_dashboard_cash_ladder_from_flow_v2(u,current_date,horizon,flow)),
 shifted AS(
  SELECT b.flow_date,b.balance_with_scheduled_vesting base_value,
   b.balance_with_scheduled_vesting+coalesce((SELECT sum((s->>'scenario_amount_brl')::numeric)
    FROM jsonb_array_elements(selected)s WHERE p_hypothetical_date<=b.flow_date
     AND b.flow_date<(s->>'available_date')::date),0) scenario_value FROM baseline b
 )
 SELECT min(flow_date) FILTER(WHERE base_value<0),min(base_value),
  min(flow_date) FILTER(WHERE scenario_value<0),min(scenario_value)
 INTO base_gap,base_worst,scenario_gap,scenario_worst FROM shifted;
 RETURN jsonb_build_object('version','vesting-anticipation-scenario-v411-read-only','scenario_only',true,
  'hypothetical_date',p_hypothetical_date,'selected_awards',selected,'selected_amount_brl',round(total,2),
  'valuation_basis',CASE WHEN policy ? 'policy' THEN 'scheduled_net_valuation_not_a_confirmed_corporate_payment' ELSE 'legacy_cached_award_valuation' END,
  'current_model',jsonb_build_object('first_negative_date',base_gap,'worst_balance',round(base_worst,2)),
  'scenario',jsonb_build_object('first_negative_date',scenario_gap,'worst_balance',round(scenario_worst,2)),
  'guardrail',CASE WHEN policy ? 'policy' THEN 'Simulação de disponibilidade com valor líquido estimado. Não confirma fechamento, pagamento, imposto ou alteração do calendário.' ELSE 'Simulação com a base de valor indicada em cada concessão. Não confirma pagamento ou alteração do calendário.' END);
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_vesting_scenario_v1(text[],date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_vesting_scenario_v1(text[],date) TO authenticated,service_role;
