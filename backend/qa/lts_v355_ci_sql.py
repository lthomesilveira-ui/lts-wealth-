"""Canonical card obligations in real reader bodies; synthetic owners/sources only."""
from pathlib import Path
import json

R=Path(__file__).resolve().parents[2]
def sql(path):return (R/path).read_text()
print(r'''
BEGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.jwt()RETURNS jsonb LANGUAGE sql AS $$SELECT'{"email":"viewer@example.invalid"}'::jsonb$$;
CREATE TABLE public.lts_product_read_cache(user_id uuid PRIMARY KEY,payload_version text,payload jsonb,refreshed_at timestamptz,source text);
CREATE TABLE public.lts_dashboard_cockpit_cache(user_id uuid PRIMARY KEY,as_of date,source_product_refreshed_at timestamptz,payload jsonb);
CREATE TABLE public.lts_access_audit(user_id uuid,email text,action text,meta jsonb);
CREATE TABLE public.qa_card_sources(user_id uuid PRIMARY KEY,cards jsonb);
CREATE FUNCTION public.lts_browser_assert_user_v1()RETURNS uuid LANGUAGE sql AS $$SELECT current_setting('lts.qa_owner')::uuid$$;
CREATE FUNCTION public.lts_card_read_start_v269(uuid)RETURNS text LANGUAGE sql AS $$SELECT'qa-revision'::text$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $3$$;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(uuid)RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT cards FROM public.qa_card_sources WHERE user_id=$1$$;
CREATE FUNCTION public.lts_c6_completeness_state_v269(uuid)RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('complete',cards->'complete','incomplete_families','["c6"]'::jsonb)FROM public.qa_card_sources WHERE user_id=$1$$;
CREATE FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_product_read_cached_v1(uuid)RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('payload_version',payload_version,'payload',payload,'refreshed_at',refreshed_at)FROM public.lts_product_read_cache WHERE user_id=$1$$;
CREATE FUNCTION public.lts_product_payload_fix86_v36(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT payload FROM public.lts_product_read_cache WHERE user_id=$1$$;
CREATE FUNCTION public.lts_browser_enrich_flow_bank_gross_v1(jsonb)RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$SELECT $1$$;
CREATE FUNCTION public.lts_apply_current_liquidity_anchor_v1(uuid)RETURNS void LANGUAGE plpgsql AS $$BEGIN RETURN;END$$;
CREATE FUNCTION public.lts_refresh_dashboard_cockpit_v1(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT payload FROM public.lts_dashboard_cockpit_cache WHERE user_id=$1$$;
CREATE FUNCTION public.lts_wealth_executive_report_v5(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT payload->'wealth_executive'FROM public.lts_product_read_cache WHERE user_id=$1$$;
CREATE FUNCTION public.lts_dashboard_cockpit_top_actions_v1(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT'[]'::jsonb$$;
CREATE FUNCTION public.lts_card_operating_view_v2(uuid,date)RETURNS jsonb LANGUAGE sql AS $$SELECT payload->'card_operating'FROM public.lts_product_read_cache WHERE user_id=$1$$;
CREATE FUNCTION public.lts_card_classification_review_v2(uuid,integer)RETURNS jsonb LANGUAGE sql AS $$SELECT'{"pending_groups":0,"pending_lines":0,"pending_value":0,"safe_suggestion_groups":0,"all_suggestion_groups":0}'::jsonb$$;
''')
for name in ['lts_browser_product_v1','lts_browser_dashboard_cockpit_v1','lts_card_operating_view_v3']:
    print(sql(f'backend/qa/fixtures/v355_{name}_original.sql')+';')

def cycle(month,due,value,paid=False,**extra):
    return dict(month=month,reference_month=month,due_date=due,amount=value,settlement_confirmed=paid,**extra)
cards=dict(version='card-cycles-v226',complete=True,cards=[
    dict(family='c6',name='C6 Carbon',bank='C6',cycles=[cycle('2026-12-01','2026-12-07',30),cycle('2026-10-01','2026-10-05',7,True),cycle('2026-11-01','2026-11-05',40)]),
    dict(family='aeternum',name='Visa Aeternum',bank='Bradesco',cycles=[cycle('2026-10-01','2026-10-25',100,payment_status='payment_not_reported')]),
    dict(family='bradesco_prime',name='Visa Infinite Prime',bank='Bradesco',cycles=[cycle('2026-11-01','2026-11-20',3)]),
    dict(family='itau_mastercard',name='Mastercard Black',bank='Itaú',cycles=[cycle('2026-11-01','2026-11-16',20)]),
    dict(family='itau_visa',name='Visa Infinite',bank='Itaú',cycles=[]),
])
print("INSERT INTO public.qa_card_sources VALUES('00000000-0000-4000-8000-000000000001',$fixture$"+json.dumps(cards,ensure_ascii=False)+"$fixture$);")
other=dict(version='card-cycles-v226',complete=True,cards=[dict(family='c6',name='Other owner card',bank='C6',cycles=[cycle('2026-11-01','2026-11-05',999)])])
print("INSERT INTO public.qa_card_sources VALUES('00000000-0000-4000-8000-000000000002',$fixture$"+json.dumps(other)+"$fixture$);")
print(r'''
INSERT INTO public.lts_product_read_cache
SELECT user_id,'lts-product-fix86-v36',jsonb_build_object('untouched_cash',1234.56,'untouched_expenses','[{"amount":-12,"category":"Original"}]'::jsonb,
'updates',jsonb_build_object('freshness',jsonb_build_object('today',current_date),'document_change_summary_version','document-change-summary-v1'),
'wealth_executive',jsonb_build_object('reconciliation_version','wealth-summary-current-effective-v240','summary','{"assets_central":2000,"net_worth_central":1500,"known_debt_total":500}'::jsonb,'distribution','[]'::jsonb),
'card_operating','{"next_due":{"card_name":"Old paid C6","amount":7,"due_date":"2026-10-05"},"legacy_installment_reference":42}'::jsonb,
'dashboard_cockpit',jsonb_build_object('cards','{"next_due":{"card_name":"Old paid C6","amount":7,"due_date":"2026-10-05"}}'::jsonb,'planning_audited','{"first_negative_date":"2027-01-01"}'::jsonb)),
current_date::timestamptz,'synthetic'FROM public.qa_card_sources;
INSERT INTO public.lts_dashboard_cockpit_cache SELECT user_id,current_date,refreshed_at,payload->'dashboard_cockpit'FROM public.lts_product_read_cache;
SELECT set_config('lts.qa_owner','00000000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE v355_before(kind text,j jsonb);
INSERT INTO v355_before VALUES('product',public.lts_browser_product_v1()),('cockpit',public.lts_browser_dashboard_cockpit_v1()),('operating',public.lts_card_operating_view_v3('00000000-0000-4000-8000-000000000001',current_date)),('source',(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.qa_card_sources x));
''')
print(sql('backend/patches/v355/canonical_card_obligations.sql'))
patch=sql('backend/patches/v355/readers.sql')
print(patch)
print("CREATE TEMP TABLE v355_patch(sql text);INSERT INTO v355_patch VALUES($patchfixture$"+patch+"$patchfixture$);")
print(r'''
CREATE TEMP TABLE v355_after(kind text,j jsonb);
INSERT INTO v355_after VALUES('product',public.lts_browser_product_v1()),('cockpit',public.lts_browser_dashboard_cockpit_v1()),('operating',public.lts_card_operating_view_v3('00000000-0000-4000-8000-000000000001',current_date));
DO $test$DECLARE b jsonb;a jsonb;v jsonb;m text;BEGIN
SELECT j->'mvp'INTO b FROM v355_before WHERE kind='product';SELECT j->'mvp'INTO a FROM v355_after WHERE kind='product';
IF(b-ARRAY['card_operating','dashboard_cockpit'])IS DISTINCT FROM(a-ARRAY['card_operating','dashboard_cockpit'])
OR(b->'dashboard_cockpit'-'cards')IS DISTINCT FROM(a->'dashboard_cockpit'-'cards')THEN RAISE EXCEPTION 'Unrelated product finance changed';END IF;
IF a#>>'{card_operating,next_due,family}'<>'aeternum'OR a#>>'{dashboard_cockpit,cards,next_due,family}'<>'aeternum'
OR(SELECT j#>>'{cards,next_due,family}'FROM v355_after WHERE kind='cockpit')<>'aeternum'
OR(SELECT j#>>'{next_due,family}'FROM v355_after WHERE kind='operating')<>'aeternum'THEN RAISE EXCEPTION 'Consumers disagree or keep paid cycle';END IF;
IF(SELECT j FROM v355_before WHERE kind='source')IS DISTINCT FROM(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.qa_card_sources x)
THEN RAISE EXCEPTION 'Source changed';END IF;
FOR v IN SELECT public.lts_card_obligations_v355(cards,dt)FROM public.qa_card_sources CROSS JOIN(VALUES(date'2026-10-26'),(date'2026-11-01'))t(dt)WHERE user_id='00000000-0000-4000-8000-000000000001'LOOP
IF v->>'complete'<>'true'OR v#>>'{next_due,family}'<>'aeternum'OR(v->>'next_obligations_total')::numeric<>163 OR(v->>'following_cycles_total')::numeric<>30
OR(SELECT x->>'month'FROM jsonb_array_elements(v->'targets')x WHERE x->>'family'='c6')<>'2026-11-01'
THEN RAISE EXCEPTION 'Rollover, unsorted cycle or targets sum failed';END IF;END LOOP;
PERFORM set_config('lts.qa_owner','00000000-0000-4000-8000-000000000002',true);
IF public.lts_browser_product_v1()#>>'{mvp,card_operating,next_due,card_name}'<>'Other owner card'
OR public.lts_browser_dashboard_cockpit_v1()#>>'{cards,next_due,amount}'<>'999'THEN RAISE EXCEPTION 'Other owner not isolated';END IF;
PERFORM set_config('lts.qa_owner','00000000-0000-4000-8000-000000000001',true);
BEGIN EXECUTE(SELECT sql FROM v355_patch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
IF m NOT LIKE'V355_SOURCE_CHANGED:%'THEN RAISE EXCEPTION 'Reader replay lease failed';END IF;
EXECUTE'SET LOCAL ROLE authenticated';
BEGIN PERFORM public.lts_card_obligations_v355('{}',current_date);RAISE EXCEPTION 'Private helper exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
EXECUTE'RESET ROLE';END$test$;
CREATE TEMP TABLE v355_cases(name text,path text[],value jsonb);
INSERT INTO v355_cases VALUES
('source version','{version}','"wrong"'),('missing completeness','{complete}','null'),('incomplete source','{complete}','false'),
('missing array','{cards}','null'),('unknown amount','{cards,1,cycles,0,amount}','null'),
('malformed amount','{cards,1,cycles,0,amount}','"100"'),('invalid due date','{cards,1,cycles,0,due_date}','"2026-02-30"'),
('conflicting month','{cards,1,cycles,0,reference_month}','"2026-11-01"'),
('false typed settlement','{cards,1,cycles,0,settlement_confirmed}','"true"'),
('incomplete card','{cards,1,complete}','false');
DO $test$DECLARE r record;v jsonb;b jsonb;BEGIN SELECT cards INTO b FROM public.qa_card_sources WHERE user_id='00000000-0000-4000-8000-000000000001';
FOR r IN SELECT*FROM v355_cases LOOP
v:=public.lts_card_obligations_v355(jsonb_set(b,r.path,r.value,true),date'2026-11-01');
IF v->>'complete'<>'false'OR v->'next_due'IS DISTINCT FROM'null'::jsonb OR v->'next_obligations_total'IS DISTINCT FROM'null'::jsonb
THEN RAISE EXCEPTION 'Uncertain source shown as complete: %',r.name;END IF;END LOOP;
v:=public.lts_card_obligations_v355(jsonb_set(b,'{cards}',(b->'cards')||jsonb_build_array(b#>'{cards,1}')),date'2026-11-01');
IF v->>'complete'<>'false'THEN RAISE EXCEPTION 'Duplicate card accepted';END IF;
v:=public.lts_card_obligations_v355(jsonb_set(b,'{cards,1,cycles}',(b#>'{cards,1,cycles}')||(b#>'{cards,1,cycles}')),date'2026-11-01');
IF v->>'complete'<>'false'THEN RAISE EXCEPTION 'Duplicate cycle accepted';END IF;
v:=public.lts_card_obligations_v355(jsonb_set(b,'{cards,1,cycles,0,payment_status}','"partial"'),date'2026-11-01');
IF v#>>'{next_due,family}'<>'aeternum'OR v#>>'{next_due,amount}'<>'100'THEN RAISE EXCEPTION 'Partial payment hidden or invented remaining amount';END IF;
v:=public.lts_card_obligations_v355(jsonb_set(b,'{cards,1,cycles,0,due_date}','null'),date'2026-11-01');
IF v#>>'{next_due,due_date}'IS NOT NULL OR v#>>'{next_due,state}'<>'due_date_unconfirmed'THEN RAISE EXCEPTION 'Undated cycle got invented date';END IF;
v:=public.lts_card_obligations_v355(jsonb_set(b,'{cards,1,cycles,0,amount}','0'),date'2026-11-01');
IF v#>>'{next_due,family}'<>'c6'OR jsonb_array_length(v->'nonpayable_cycles')<>1 THEN RAISE EXCEPTION 'Zero cycle became payable';END IF;
END$test$;
SELECT jsonb_build_object('pass',true,'version',355,'invalid_source_cases',(SELECT count(*)+2 FROM v355_cases),'same_canonical_targets',true,'unrelated_financial_payloads_preserved',true,'private_helpers',true,'owner_isolation',true,'past_partial_and_rollover_preserved',true,
'synthetic_cards',cards,'synthetic_projection',public.lts_card_obligations_v355(cards,date'2026-10-26'),
'synthetic_rollover_projection',public.lts_card_obligations_v355(cards,date'2026-11-01'),
'synthetic_after_payment_projection',public.lts_card_obligations_v355(jsonb_set(cards,'{cards,1,cycles,0,settlement_confirmed}','true'),date'2026-11-01'))
FROM public.qa_card_sources WHERE user_id='00000000-0000-4000-8000-000000000001';
ROLLBACK;
''')
