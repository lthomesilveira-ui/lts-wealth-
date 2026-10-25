"""C6 compatibility detail agrees with the canonical known forecast, without new money."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v311_ci.py'))
run,U=base['run'],base['U']
OTHER='00000000-0000-4000-8000-000000000099'
qa=ROOT/'qa/v321';qa.mkdir(parents=True,exist_ok=True)
run("""
CREATE TABLE public.financial_events(id uuid,amount numeric);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,line_key text,amount numeric);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text);
CREATE TABLE public.lts_category_catalog(user_id uuid,category text);
CREATE TABLE public.lts_semantic_rule(user_id uuid,id bigint,rule jsonb);
CREATE TABLE public.source_documents(id uuid,metadata jsonb);
CREATE TABLE public.v321_payload(user_id uuid PRIMARY KEY,payload jsonb);
CREATE SEQUENCE public.v321_prepared_calls;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb;BEGIN PERFORM nextval('public.v321_prepared_calls');SELECT payload INTO result FROM public.v321_payload WHERE user_id=p_user_id;RETURN coalesce(result,'{"cards":[]}'::jsonb);END$$;
""")
old=(ROOT/'backend/qa/v321_prior_effective.sql').read_text()
run(old)
assert run("SELECT md5(pg_get_functiondef('public.lts_card_invoices_effective_v226(uuid)'::regprocedure));")=='41019409fd6791c9cc53d79c66ee2a39'
run("REVOKE ALL ON FUNCTION public.lts_card_invoices_effective_v226(uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.lts_card_invoices_effective_v226(uuid) TO service_role;")
run(f"""
INSERT INTO public.card_invoices VALUES
('00000000-0000-4000-8000-000000000301','{U}','fixture-c6-next','C6 Carbon','fixture-c6',(date_trunc('month',current_date)+interval '1 month')::date,(date_trunc('month',current_date)+interval '1 month')::date+4,'open',100,'fixture', '{{"preserve":"original-document"}}',now()),
('00000000-0000-4000-8000-000000000302','{U}','fixture-c6-later','C6 Carbon','fixture-c6',(date_trunc('month',current_date)+interval '2 month')::date,(date_trunc('month',current_date)+interval '2 month')::date+4,'projected',70,'fixture','{{"preserve":"original-document"}}',now()),
('00000000-0000-4000-8000-000000000303','{U}','fixture-c6-history','C6 Carbon','fixture-c6',(date_trunc('month',current_date)-interval '1 month')::date,(date_trunc('month',current_date)-interval '1 month')::date+4,'paid',85,'fixture','{{"items":[{{"description":"Historical purchase","amount":85}}]}}',now()),
('00000000-0000-4000-8000-000000000304','{U}','fixture-c6-current','C6 Carbon','fixture-c6',date_trunc('month',current_date)::date,date_trunc('month',current_date)::date+24,'open',90,'fixture','{{"items":[{{"description":"Current purchase","amount":90}}]}}',now());
INSERT INTO public.v311_rows VALUES('{U}','00000000-0000-4000-8000-000000000305','C6','c6','C6 Carbon','1234','1234',current_date,current_date,(date_trunc('month',current_date)+interval '1 month')::date,(date_trunc('month',current_date)+interval '1 month')::date+4,'PENDING',30,'Received C6 item','Casa','fixture',1,3,false,NULL,now());
INSERT INTO public.v321_payload SELECT '{U}',jsonb_build_object('version','card-cycles-v226','as_of',current_date,'complete',true,'cards',jsonb_build_array(jsonb_build_object('family','c6','bank','C6','name','C6 Carbon','last4','1234','status','ACTIVE','cycles',jsonb_build_array(
jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',(date_trunc('month',current_date)+interval '1 month')::date+4,'amount',100,'basis','received_and_projected_installments','observed_at','2020-01-01T12:00:00Z','item_count',2,'unclassified',0,'items',jsonb_build_array(
jsonb_build_object('description','Received C6 item','amount',30,'category','Casa','category_basis','fixture','provider_status','PENDING','last4','1234','installment_number',1,'total_installments',3),
jsonb_build_object('description','Projected C6 item','amount',70,'category','Casa','category_basis','fixture','provider_status','PROJECTED','last4','1234','installment_number',2,'total_installments',3))),
jsonb_build_object('month',(date_trunc('month',current_date)+interval '2 month')::date,'due_date',(date_trunc('month',current_date)+interval '2 month')::date+4,'amount',70,'basis','derived_current_installments','item_count',1,'unclassified',0,'items',jsonb_build_array(jsonb_build_object('description','Projected C6 item','amount',70,'category','Casa','category_basis','fixture','provider_status','PROJECTED','last4','1234','installment_number',3,'total_installments',3))),
jsonb_build_object('month',(date_trunc('month',current_date)+interval '3 month')::date,'due_date',NULL,'amount',12,'basis','derived_current_installments','item_count',1,'unclassified',0,'items',jsonb_build_array(jsonb_build_object('description','Undated C6 item','amount',12,'category','Casa','category_basis','fixture','provider_status','PROJECTED','last4','1234')))))));
""")
query=f"SELECT jsonb_agg(to_jsonb(r) ORDER BY card_name,reference_month) FROM public.lts_card_invoices_effective_v226('{U}')r;"
before=json.loads(run(query))
future=lambda rows:[x for x in rows if x['legacy_id'] in('fixture-c6-next','fixture-c6-later')]
assert [float(x['amount']) for x in future(before)]==[100,70]
assert sum(float(i['amount']) for i in future(before)[0]['metadata']['items'])==30
assert future(before)[1]['metadata'].get('items') is None
finger="SELECT jsonb_build_object('invoices',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.card_invoices s),'sources',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),'rows',(SELECT jsonb_agg(to_jsonb(s) ORDER BY source_id) FROM public.v311_rows s),'payload',(SELECT jsonb_agg(to_jsonb(s) ORDER BY user_id) FROM public.v321_payload s))"
frozen=run(finger)
attrs="SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_card_invoices_effective_v226(uuid)'::regprocedure;"
attributes=run(attrs)
patch=(ROOT/'backend/patches/v321/effective_c6_detail.sql').read_text()
run(patch)
assert run(finger)==frozen and run(attrs)==attributes
run("SELECT setval('public.v321_prepared_calls',1,false);")
after=json.loads(run(query))
assert run('SELECT last_value FROM public.v321_prepared_calls;')=='1','Prepared cycles evaluated more than once'
for a,b in zip(before,after):
 assert {k:v for k,v in a.items() if k!='metadata'}=={k:v for k,v in b.items() if k!='metadata'}
 if a['legacy_id'] not in('fixture-c6-next','fixture-c6-later'):assert a==b
 else:
  assert b['metadata']['preserve']=='original-document'
  assert b['metadata']['known_items_sum_matches_amount'] and b['metadata']['items_contain_projections']
  assert b['metadata']['replaced_detail_snapshot']['items']==a['metadata'].get('items',[])
  assert sum(float(i['amount']) for i in b['metadata']['items'])==float(b['amount'])
assert len(after)==len(before)
assert len(future(after)[0]['metadata']['items'])==2 and len(future(after)[1]['metadata']['items'])==1
assert run(query.replace(U,OTHER))==''
mutation_cases=[
 "jsonb_set(payload,'{cards,0,cycles,0,amount}','101')",
 "jsonb_set(payload,'{cards,0,cycles,0,complete}','false')",
 "jsonb_set(payload,'{cards,0,cycles,0,amount}','null')",
 "jsonb_set(payload,'{cards,0,cycles,0,due_date}','null')",
 "jsonb_set(payload,'{cards,0,cycles,0,items,1,amount}','69')",
 "jsonb_set(payload,'{cards,0,cycles,0,items}','null')",
 "jsonb_set(payload,'{cards,0,cycles,0,items}','{}')",
 "jsonb_set(payload,'{cards,0,cycles,0,items}','[]')",
 "jsonb_set(payload,'{cards,0,cycles}',(payload#>'{cards,0,cycles}')||jsonb_build_array(payload#>'{cards,0,cycles,0}'),false)",
]
for mutation in mutation_cases:
 result=json.loads(run('BEGIN;'+f"UPDATE public.v321_payload SET payload={mutation} WHERE user_id='{U}';"+query+'ROLLBACK;'))
 assert len(result)==len(before)
 assert future(result)[0]==future(before)[0],mutation
 assert future(result)[1]==future(after)[1]
assert run(finger)==frozen
run(patch);assert json.loads(run(query))==after and run(attrs)==attributes
drift=old.replace('AS $function$','AS $function$\n-- drift\n',1)
run('BEGIN;'+drift+patch+'ROLLBACK;',False)
assert run(finger)==frozen
assert run("SELECT NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE oid='public.lts_card_invoices_effective_v226(uuid)'::regprocedure;")=='t'
run(f"SET ROLE anon;SELECT * FROM public.lts_card_invoices_effective_v226('{U}');",False)
run(f"SET ROLE authenticated;SELECT * FROM public.lts_card_invoices_effective_v226('{U}');",False)
plan=json.loads(run('EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) '+query))
native=json.loads(run(f"SELECT payload FROM public.v321_payload WHERE user_id='{U}';"))
for cy,invoice in zip(native['cards'][0]['cycles'][:2],future(after)):
 cy['items']=invoice['metadata']['items'];cy['item_count']=len(cy['items'])
(qa/'native-card-cycles.json').write_text(json.dumps(native))
for name,value in [('native-before.json',before),('native-after.json',after),('plan-after.json',plan)]:
 (qa/name).write_text(json.dumps(value))
result=dict(passed=True,engine='postgresql17',old_partial_and_empty_detail_reproduced=True,
 future_c6_known_item_sums_exact=True,received_and_projected_items_both_present=True,
 money_dates_identity_status_and_non_c6_exact=True,historical_and_current_c6_exact=True,
 no_undated_cycle_or_cash_event_created=True,original_metadata_snapshot_preserved=True,
 unsafe_composition_cases_rejected=len(mutation_cases),ambiguous_cycle_does_not_duplicate_rows=True,
 prepared_cycles_evaluated_once=True,source_and_financial_rows_exact=True,
 function_attributes_acl_replay_and_drift_guarded=True,explain_analyze_recorded=True,
 production_performance_benchmark=False,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
