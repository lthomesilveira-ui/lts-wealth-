-- V414: reuse complete predecessor results within one payload invocation.
-- No cache, financial-source, privilege, authentication or timeout change.
BEGIN;
DO $guard$
DECLARE item record;target regprocedure;
BEGIN
 FOR item IN SELECT * FROM (VALUES
  ('public.lts_product_payload_fix86_v2(uuid)','74dddd4262aa0393f20ccc808c9ddbc5'),
  ('public.lts_mvp_product_payload_v1(uuid)','182b30b47660f25ef37f9443b478da7f'),
  ('public.lts_dashboard_horizon_v1(uuid)','7448a5695cfc951e6177e687e7e34641')
 ) AS expected(signature,definition_md5) LOOP
  target:=to_regprocedure(item.signature);
  IF target IS NULL OR md5(pg_get_functiondef(target))<>item.definition_md5
   THEN RAISE EXCEPTION 'V414 payload predecessor differs: %; review before applying',item.signature; END IF;
 END LOOP;
 -- Inlining must retain the effective role of the original definer boundary.
 IF (SELECT proowner FROM pg_proc
      WHERE oid='public.lts_mvp_product_payload_v1(uuid)'::regprocedure)
    IS DISTINCT FROM
    (SELECT proowner FROM pg_proc
      WHERE oid='public.lts_dashboard_horizon_v1(uuid)'::regprocedure)
  THEN RAISE EXCEPTION 'V414 horizon and MVP definer owners must match'; END IF;
END $guard$;

-- V414: share existing complete read results within each invocation.
CREATE OR REPLACE FUNCTION public.lts_product_payload_fix86_v2(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- V414: evaluate the existing complete predecessor exactly once per invocation.
WITH base AS MATERIALIZED (
 SELECT public.lts_mvp_product_payload_v10_fix86(p_user_id) AS j
)
select (select j from base)
|| jsonb_build_object(
  'version','lts-product-fix86-plus-v2',
  'baseline','FIX86 Legacy Reference Release',
  'navigation',jsonb_build_array('Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Financiamentos','Planejamento','Lançar / Importar','Configurações'),
  'stage',jsonb_build_object('fix86_engine','18_pass_2_evidence_visual_partial','daily_flow','v6_13_columns','dashboard_renderer','certified_fix83_fix86_single','beyond_fix86','active'),
  'product_contract',coalesce((select j->'product_contract' from base),'{}'::jsonb)
    || jsonb_build_object(
      'manual_homologation_ready',false,
      'c6_1072_58_status','evidence-open; no invented debit',
      'own_transfer_destinations','2 unresolved; neutral clearing',
      'visual_regression_gate','pending browser verification',
      'fix86_is_floor_not_destination',true
    )
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_mvp_product_payload_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
-- V414: reuse the same position and projection audit inside the unchanged horizon query.
with pos as MATERIALIZED (select public.lts_current_evidence_position_v1(p_user_id) j),scen as (select public.lts_cashflow_scenarios_v1(p_user_id,'2026-08-19','2026-12-31') j),audit as MATERIALIZED (select public.lts_projection_year_audit_v1(p_user_id,2026,2031) j),horizon as (select (with p as (
 select j from pos
), a as (
 select j from audit
), yrs as (
 select generate_series(2026,2031) y
), cf as (
 select extract(year from event_date)::int y, sum(signed_amount) net
 from public.lts_corrected_cashflow_v1(p_user_id,'2026-08-19','2031-12-31')
 group by 1
), audit_rows as (
 select (x->>'year')::int y,x from a, jsonb_array_elements(a.j->'years') x
), base as (
 select coalesce((p.j->>'liquidity_through_d3')::numeric,0) starting_liquidity from p
), timeline as (
 select yrs.y,
        coalesce(cf.net,0) net_flow,
        (select starting_liquidity from base)+sum(coalesce(cf.net,0)) over(order by yrs.y) ending_liquidity,
        ar.x->>'projection_confidence' confidence,
        ar.x->'salary' salary,
        ar.x->'cipo_396' cipo_396,
        coalesce((ar.x->>'volvo_events')::int,0) volvo_events,
        coalesce((ar.x->>'coopharma_events')::int,0) coopharma_events
 from yrs left join cf on cf.y=yrs.y left join audit_rows ar on ar.y=yrs.y
)
select jsonb_build_object(
 'version','dashboard-horizon-v1',
 'starting_realizable_liquidity',(select starting_liquidity from base),
 'years',jsonb_agg(jsonb_build_object(
   'year',y,'net_flow',round(net_flow,2),'ending_liquidity',round(ending_liquidity,2),
   'cash_status',case when ending_liquidity>=0 then 'covered' else 'rupture' end,
   'confidence',confidence,'decision_grade',case when confidence='higher' then true else false end,
   'salary',salary,'cipo_396',cipo_396,'volvo_events',volvo_events,'coopharma_events',coopharma_events
 ) order by y),
 'first_modelled_rupture_year',(select min(y) from timeline where ending_liquidity<0),
 'first_decision_grade_rupture_year',(select min(y) from timeline where ending_liquidity<0 and confidence='higher'),
 'guardrail','Rupture is only decision-grade when projection confidence is higher. 2030/2031 currently require salary-continuity repair before long-horizon conclusions.'
) from timeline) AS j),commits as (select public.lts_commitments_summary_v1(p_user_id,'2026-08-19') j),cipo as (select public.lts_cipo_396_summary_v1(p_user_id) j),exp as (select public.lts_expense_history_summary_v1(p_user_id,'2013-01-01','2026-08-19') j),qa as (select public.lts_engine_qa_suite_v1(p_user_id) j),flow as (select public.lts_daily_flow_mvp_v1(p_user_id,'2026-08-19','2026-10-31') j),
assets as (select coalesce(jsonb_agg(jsonb_build_object('asset_type',asset_type,'asset_name',asset_name,'as_of_date',as_of_date,'value_brl',value_brl,'liquidity_class',liquidity_class,'is_available_now',is_available_now,'availability_note',availability_note,'quantity',quantity,'unit_price',unit_price,'fx_rate',fx_rate) order by is_available_now desc,value_brl desc),'[]'::jsonb) j from public.asset_positions where user_id=p_user_id),
accounts as (select coalesce(jsonb_agg(jsonb_build_object('id',id,'institution',institution,'account_name',account_name,'balance',coalesce((metadata->>'balance')::numeric,0),'as_of',metadata->>'balance_as_of','active',is_active) order by institution),'[]'::jsonb) j from public.accounts where user_id=p_user_id and is_active=true),
inbox as (select jsonb_build_object('queued',count(*) filter(where status='queued'),'review',count(*) filter(where status in ('review','needs_review')),'applied',count(*) filter(where status='applied'),'total',count(*)) j from public.lts_input_inbox where user_id=p_user_id),
cardinv as (select coalesce(jsonb_agg(jsonb_build_object('card_name',card_name,'reference_month',reference_month,'due_date',due_date,'status',status,'amount',amount,'source',source,'metadata',metadata) order by due_date desc),'[]'::jsonb) j from public.card_invoices where user_id=p_user_id),
cardrec as (select coalesce(jsonb_agg(jsonb_build_object('invoice_id',invoice_id,'card_name',card_name,'due_date',due_date,'detail_lines',detail_lines,'detail_gross',detail_gross,'invoice_total',invoice_total,'delta',delta,'reconciled',reconciled) order by due_date desc),'[]'::jsonb) j from public.lts_card_invoice_detail_reconciliation where user_id=p_user_id),
manualcard as (select coalesce(jsonb_agg(jsonb_build_object('id',id,'purchase_date',purchase_date,'card_name',card_name,'amount',amount,'description',description,'category',category,'cost_center',cost_center,'counterparty',counterparty,'status',status,'created_at',created_at) order by purchase_date desc,created_at desc),'[]'::jsonb) j from public.lts_manual_card_purchase where user_id=p_user_id),
carddetail as (select coalesce(jsonb_agg(jsonb_build_object('purchase_date',purchase_date,'invoice_due_date',invoice_due_date,'card_name',card_name,'card_final',card_final,'holder',holder,'description',description_normalized,'category',category,'installments',installments,'installment_number',installment_number,'installment_amount',installment_amount,'purchase_total',purchase_total) order by purchase_date desc),'[]'::jsonb) j from (select * from public.lts_card_purchase_detail where user_id=p_user_id order by purchase_date desc limit 120) q)
select jsonb_build_object('version','mvp-product-payload-v4','as_of','2026-08-19','navigation',jsonb_build_array('Dashboard','Fluxo','Gastos','Patrimônio','Compromissos','Lançar / Importar'),
'dashboard',jsonb_build_object('position',(select j from pos),'scenarios',(select j from scen),'year_horizon',(select j from horizon),'projection_audit',(select j from audit),'qa',(select j from qa)),
'flow',(select j from flow),
'expenses',(select j from exp) || jsonb_build_object('cards',jsonb_build_object('invoices',(select j from cardinv),'reconciliation',(select j from cardrec),'recent_purchases',(select j from carddetail),'manual_unbilled',(select j from manualcard))),
'wealth',jsonb_build_object('accounts',(select j from accounts),'assets',(select j from assets),'cipo_396',(select j from cipo)),
'commitments',(select j from commits),
'input',jsonb_build_object('single_inbox',true,'phrase_preview',true,'phrase_approve',true,'photo_upload',true,'pdf_upload',true,'file_import',true,'write_requires_review',true,'status',(select j from inbox)),
'backup',jsonb_build_object('cloud_persistence',true,'export_json',true,'export_excel','next','export_csv','next','restore','next'),
'guardrails',jsonb_build_array('Dashboard is home.','Functional homologation and live promotion are separate gates.','2030/2031 rupture cannot be decision-grade while salary continuity is partial/missing.','Internal transfers are neutral to consolidated cash and appear in a clearing bucket until destination is proven.','Card purchases never create bank cash outflow before invoice payment.','Coopharma reduces economic availability without duplicate bank debit.','CIPÓ 396 keeps financing and property investments analytically separate.'));
$function$;

DO $guard$
DECLARE item record;target regprocedure;
BEGIN
 FOR item IN SELECT * FROM (VALUES
  ('public.lts_product_payload_fix86_v2(uuid)',false),
  ('public.lts_mvp_product_payload_v1(uuid)',true)
 ) AS expected(signature,security_definer) LOOP
  target:=to_regprocedure(item.signature);
  IF target IS NULL OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=target
    AND(p.prosecdef IS DISTINCT FROM item.security_definer OR p.provolatile<>'v'
      OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public']
      OR p.proacl::text IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'))
   OR has_function_privilege('anon',target,'EXECUTE')
   OR has_function_privilege('authenticated',target,'EXECUTE')
   OR NOT has_function_privilege('service_role',target,'EXECUTE')
   THEN RAISE EXCEPTION 'V414 must preserve existing private payload attributes: %',item.signature; END IF;
 END LOOP;
 IF md5(pg_get_functiondef('public.lts_dashboard_horizon_v1(uuid)'::regprocedure))
   <>'7448a5695cfc951e6177e687e7e34641'
  THEN RAISE EXCEPTION 'V414 must preserve the standalone horizon definition'; END IF;
END $guard$;
COMMIT;
