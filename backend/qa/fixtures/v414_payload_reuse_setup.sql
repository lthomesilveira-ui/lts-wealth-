-- Disposable synthetic fixtures only. No private production rows.
SET TimeZone='America/Sao_Paulo';
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $roles$;
CREATE SCHEMA qa_v414;
CREATE TABLE qa_v414.calls(name text PRIMARY KEY,n integer NOT NULL);
CREATE TABLE qa_v414.config(key text PRIMARY KEY,value jsonb);
INSERT INTO qa_v414.config VALUES
 ('position','{"liquidity_through_d3":1000,"fixture":"position"}'),
 ('audit','{"years":[{"year":2026,"projection_confidence":"higher","salary":{"months":12},"cipo_396":{"events":2},"volvo_events":1,"coopharma_events":3},{"year":2027,"projection_confidence":"lower"},{"year":2028,"projection_confidence":"higher"},{"year":2029,"projection_confidence":"higher"},{"year":2030,"projection_confidence":"higher"},{"year":2031,"projection_confidence":"higher"}]}'),
 ('v10','{"retained":{"nested":[1,true,null]},"product_contract":{"existing":true}}'),
 ('v10_use_mvp','false'),('before_core','false');
CREATE FUNCTION qa_v414.owner() RETURNS uuid LANGUAGE sql IMMUTABLE AS $$SELECT '11111111-1111-4111-8111-111111111111'::uuid$$;
CREATE FUNCTION qa_v414.tick(p_name text) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 INSERT INTO qa_v414.calls VALUES(p_name,1) ON CONFLICT(name) DO UPDATE SET n=qa_v414.calls.n+1;
END$$;
CREATE FUNCTION qa_v414.reply(p_name text,p_user uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE result jsonb;BEGIN
 PERFORM qa_v414.tick(p_name);
 SELECT value INTO result FROM qa_v414.config WHERE key=p_name;
 RETURN result;
END$$;
CREATE FUNCTION qa_v414.counts() RETURNS jsonb LANGUAGE sql AS $$SELECT coalesce(jsonb_object_agg(name,n),'{}') FROM qa_v414.calls$$;
CREATE FUNCTION public.lts_current_evidence_position_v1(uuid) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('position',$1)$$;
CREATE FUNCTION public.lts_projection_year_audit_v1(uuid,integer,integer) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('audit',$1)$$;
CREATE TABLE qa_v414.flow(user_id uuid,event_date date,signed_amount numeric);
INSERT INTO qa_v414.flow VALUES
 (qa_v414.owner(),'2026-08-18',-999999),(qa_v414.owner(),'2026-08-19',-200.005),
 (qa_v414.owner(),'2027-01-01',-2000),(qa_v414.owner(),'2028-12-31',3000.005),
 (qa_v414.owner(),'2029-02-28',NULL),(qa_v414.owner(),'2030-06-01',-1500),
 (qa_v414.owner(),'2031-12-31',-600),(qa_v414.owner(),'2032-01-01',999999),
 ('22222222-2222-4222-8222-222222222222','2026-09-01',888888);
CREATE FUNCTION public.lts_corrected_cashflow_v1(uuid,date,date)
RETURNS TABLE(event_date date,signed_amount numeric) LANGUAGE plpgsql VOLATILE AS $$BEGIN
 PERFORM qa_v414.tick('corrected_flow');
 RETURN QUERY SELECT f.event_date,f.signed_amount FROM qa_v414.flow f WHERE f.user_id=$1 AND f.event_date BETWEEN $2 AND $3;
END$$;
INSERT INTO qa_v414.config VALUES('lts_cashflow_scenarios_v1','{"fixture":"lts_cashflow_scenarios_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_cashflow_scenarios_v1(uuid,date,date) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_cashflow_scenarios_v1',$1)$$;
INSERT INTO qa_v414.config VALUES('lts_commitments_summary_v1','{"fixture":"lts_commitments_summary_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_commitments_summary_v1(uuid,date) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_commitments_summary_v1',$1)$$;
INSERT INTO qa_v414.config VALUES('lts_cipo_396_summary_v1','{"fixture":"lts_cipo_396_summary_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_cipo_396_summary_v1(uuid) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_cipo_396_summary_v1',$1)$$;
INSERT INTO qa_v414.config VALUES('lts_expense_history_summary_v1','{"fixture":"lts_expense_history_summary_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_expense_history_summary_v1(uuid,date,date) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_expense_history_summary_v1',$1)$$;
INSERT INTO qa_v414.config VALUES('lts_engine_qa_suite_v1','{"fixture":"lts_engine_qa_suite_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_engine_qa_suite_v1(uuid) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_engine_qa_suite_v1',$1)$$;
INSERT INTO qa_v414.config VALUES('lts_daily_flow_mvp_v1','{"fixture":"lts_daily_flow_mvp_v1","sentinel":[false,123.45,null]}');
CREATE FUNCTION public.lts_daily_flow_mvp_v1(uuid,date,date) RETURNS jsonb LANGUAGE sql VOLATILE AS $$SELECT qa_v414.reply('lts_daily_flow_mvp_v1',$1)$$;
CREATE TABLE public.asset_positions(user_id uuid,asset_type text,asset_name text,as_of_date date,value_brl numeric,liquidity_class text,is_available_now boolean,availability_note text,quantity numeric,unit_price numeric,fx_rate numeric);
CREATE TABLE public.accounts(user_id uuid,id text,institution text,account_name text,metadata jsonb,is_active boolean);
CREATE TABLE public.lts_input_inbox(user_id uuid,status text);
CREATE TABLE public.card_invoices(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text,metadata jsonb);
CREATE TABLE public.lts_card_invoice_detail_reconciliation(user_id uuid,invoice_id text,card_name text,due_date date,detail_lines integer,detail_gross numeric,invoice_total numeric,delta numeric,reconciled boolean);
CREATE TABLE public.lts_manual_card_purchase(user_id uuid,id text,purchase_date date,card_name text,amount numeric,description text,category text,cost_center text,counterparty text,status text,created_at timestamptz);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,purchase_date date,invoice_due_date date,card_name text,card_final text,holder text,description_normalized text,category text,installments integer,installment_number integer,installment_amount numeric,purchase_total numeric);
INSERT INTO public.asset_positions VALUES
 (qa_v414.owner(),'cash','Fixture A','2026-08-19',123.456,'D0',true,'available',2,3,4),
 (qa_v414.owner(),'award','Fixture B','2026-08-19',789,'restricted',false,NULL,NULL,NULL,NULL);
INSERT INTO public.accounts VALUES
 (qa_v414.owner(),'one','Bank A','Active','{"balance":12.34,"balance_as_of":"2026-08-19"}',true),
 (qa_v414.owner(),'two','Bank B','Empty','{}',true),
 (qa_v414.owner(),'three','Bank C','Inactive','{"balance":999999}',false);
INSERT INTO public.lts_input_inbox SELECT qa_v414.owner(),status FROM unnest(ARRAY['queued','review','needs_review','applied','rejected']) status;
INSERT INTO public.card_invoices VALUES (qa_v414.owner(),'Synthetic','2026-08-01','2026-08-25','closed',123,'fixture','{"x":true}');
INSERT INTO public.lts_card_invoice_detail_reconciliation VALUES (qa_v414.owner(),'invoice-1','Synthetic','2026-08-25',2,123,123,0,true);
INSERT INTO public.lts_manual_card_purchase VALUES (qa_v414.owner(),'purchase-1','2026-08-17','Synthetic',25,'Synthetic item','Fixture','Fixture','Fixture','unbilled','2026-08-17T12:00:00Z');
INSERT INTO public.lts_card_purchase_detail SELECT qa_v414.owner(),'2026-01-01'::date+n,'2026-12-25','Synthetic','1234','Synthetic holder','Synthetic item '||n,'Fixture',1,1,n,n FROM generate_series(1,121)n;
CREATE FUNCTION public.lts_mvp_product_payload_v10_fix86(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM qa_v414.tick('v10');
 IF (SELECT value='true'::jsonb FROM qa_v414.config WHERE key='v10_use_mvp') THEN
  IF (SELECT value='true'::jsonb FROM qa_v414.config WHERE key='before_core') THEN
   RETURN public.lts_mvp_product_payload_v1_before_v414(p_user_id);
  ELSE RETURN public.lts_mvp_product_payload_v1(p_user_id); END IF;
 END IF;
 RETURN (SELECT value FROM qa_v414.config WHERE key='v10');
END$$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_horizon_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with p as (
 select public.lts_current_evidence_position_v1(p_user_id) j
), a as (
 select public.lts_projection_year_audit_v1(p_user_id,2026,2031) j
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
) from timeline;
$function$;

CREATE OR REPLACE FUNCTION public.lts_mvp_product_payload_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (select public.lts_current_evidence_position_v1(p_user_id) j),scen as (select public.lts_cashflow_scenarios_v1(p_user_id,'2026-08-19','2026-12-31') j),audit as (select public.lts_projection_year_audit_v1(p_user_id,2026,2031) j),horizon as (select public.lts_dashboard_horizon_v1(p_user_id) j),commits as (select public.lts_commitments_summary_v1(p_user_id,'2026-08-19') j),cipo as (select public.lts_cipo_396_summary_v1(p_user_id) j),exp as (select public.lts_expense_history_summary_v1(p_user_id,'2013-01-01','2026-08-19') j),qa as (select public.lts_engine_qa_suite_v1(p_user_id) j),flow as (select public.lts_daily_flow_mvp_v1(p_user_id,'2026-08-19','2026-10-31') j),
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

CREATE OR REPLACE FUNCTION public.lts_product_payload_fix86_v2(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
select public.lts_mvp_product_payload_v10_fix86(p_user_id)
|| jsonb_build_object(
  'version','lts-product-fix86-plus-v2',
  'baseline','FIX86 Legacy Reference Release',
  'navigation',jsonb_build_array('Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Financiamentos','Planejamento','Lançar / Importar','Configurações'),
  'stage',jsonb_build_object('fix86_engine','18_pass_2_evidence_visual_partial','daily_flow','v6_13_columns','dashboard_renderer','certified_fix83_fix86_single','beyond_fix86','active'),
  'product_contract',coalesce(public.lts_mvp_product_payload_v10_fix86(p_user_id)->'product_contract','{}'::jsonb)
    || jsonb_build_object(
      'manual_homologation_ready',false,
      'c6_1072_58_status','evidence-open; no invented debit',
      'own_transfer_destinations','2 unresolved; neutral clearing',
      'visual_regression_gate','pending browser verification',
      'fix86_is_floor_not_destination',true
    )
);
$function$;
REVOKE ALL ON FUNCTION public.lts_product_payload_fix86_v2(uuid),public.lts_mvp_product_payload_v1(uuid),public.lts_dashboard_horizon_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_product_payload_fix86_v2(uuid),public.lts_mvp_product_payload_v1(uuid),public.lts_dashboard_horizon_v1(uuid) TO service_role;
CREATE TABLE qa_v414.migration_checks(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass));
CREATE TABLE qa_v414.installed(signature text PRIMARY KEY,before_attributes jsonb,before_md5 text,after_attributes jsonb,after_md5 text);
INSERT INTO qa_v414.installed(signature,before_attributes,before_md5)
SELECT p.oid::regprocedure::text,to_jsonb(p)-'prosrc',md5(pg_get_functiondef(p.oid)) FROM pg_proc p
WHERE p.oid IN('public.lts_product_payload_fix86_v2(uuid)'::regprocedure,'public.lts_mvp_product_payload_v1(uuid)'::regprocedure,'public.lts_dashboard_horizon_v1(uuid)'::regprocedure);
DO $copy$ DECLARE name text;definition text;BEGIN
 FOREACH name IN ARRAY ARRAY['lts_product_payload_fix86_v2','lts_mvp_product_payload_v1'] LOOP
  definition:=pg_get_functiondef(('public.'||name||'(uuid)')::regprocedure);
  EXECUTE replace(definition,'FUNCTION public.'||name||'(','FUNCTION public.'||name||'_before_v414(');
 END LOOP;
END $copy$;
