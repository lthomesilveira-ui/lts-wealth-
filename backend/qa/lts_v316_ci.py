"""Source/hash-bound business natures without inferring insurance contracts."""
from pathlib import Path
import json, runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v315_ci.py'))
run,seed,U,OTHER,init=(base[k] for k in ['run','seed','U','OTHER','init'])
run((ROOT/'backend/patches/v316/verified_card_natures.sql').read_text())
run(f"INSERT INTO public.lts_category_catalog SELECT '{U}',c,true FROM unnest(ARRAY['Bebidas','Lavanderia'])c;")
fixtures=[
 (41,'E-VINO COMERCIO','5921','Groceries'),(42,'5 ASEC','7216','Services'),
 (43,'BRADESCO VID*Parc','6300','Insurance'),(44,'MAPFRE*pcl3de12','6300','Insurance'),
 (45,'E-VINO COMERCIO','5812','Groceries'),(46,'BRADESCO VID*Parc','6300','Shopping'),
 (47,'Seguradora sem identidade','6300','Insurance'),(48,'PG *5ASEC','7216','Services'),
 (49,'MAPFRE*pcl2de4','6300','Insurance'),(50,'MAPFRE*pcl4de12','6300','Insurance'),
 (51,'E-VINO COMERCIO',None,'Shopping'),(52,'MAPFRE*pcl5de12','6300','Insurance'),
 (53,'MAPFRE*pcl6de12','6300','Insurance'),(54,'MAPFRE*pcl7de12','6300','Insurance')]
for n,desc,mcc,provider in fixtures:
 run(seed(n,desc,mcc)+f"UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{provider}') WHERE id='00000000-0000-4000-8000-{n:012d}';")
run(f"""INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-mapfre-preference','MAPFRE*pcl2de4','Casa',20,'2020-02-01','2020-01-01','1234',NULL);
INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,beneficiary,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000050','Benjamin','explicit-person-only');
UPDATE public.lts_open_finance_staging SET normalized_payload='{{"status":"PENDING"}}' WHERE id='00000000-0000-4000-8000-000000000052';
UPDATE public.v312_rows SET purchase_date='2099-01-01' WHERE source_id='00000000-0000-4000-8000-000000000053';
UPDATE public.v312_rows SET reference_month=date_trunc('month',current_date)::date WHERE source_id='00000000-0000-4000-8000-000000000054';""")
queue="SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,50,NULL);"
before=json.loads(run(init+queue))
targets=json.loads(run(f"SELECT public.lts_card_verified_nature_candidates_v316('{U}');"))
assert {int(x['source_ref'].split('-')[-1]) for x in targets}=={41,42,43,44}
assert {x['category'] for x in targets}=={'Bebidas','Lavanderia','Seguros'}
for t in targets:
 assert t['evidence']['scope']=='spending_nature_only'
 assert all(t['evidence'][k] is False for k in ['contract_identity_inferred','coverage_current_inferred','owner_confirmation','beneficiary_inferred','recurring_status_inferred'])
payload=json.dumps(targets,ensure_ascii=False).replace("'","''")
apply=f"SELECT public.lts_apply_verified_card_natures_v316('{U}','{payload}'::jsonb);"
for changed in [payload.replace('a'*64,'b'*64),payload.replace('Bebidas','Casa'),payload.replace('evino-beverages','unknown-rule')]:
 run(f"SELECT public.lts_apply_verified_card_natures_v316('{U}','{changed}');",False)
run(f"SELECT public.lts_apply_verified_card_natures_v316('{OTHER}','{payload}');",False)
for mutation in [
 "UPDATE public.lts_category_catalog SET active=false WHERE category='Bebidas';",
 "UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{category}','\"Shopping\"') WHERE id='00000000-0000-4000-8000-000000000041';",
 "UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000041';",
 f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000041','Casa','explicit-override');"
]:run('BEGIN;'+mutation+apply+'ROLLBACK;',False)
finger="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s),'catalog',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s));"
finger_before=run(finger);audits=int(run('SELECT count(*) FROM public.lts_access_audit;'))
receipt=json.loads(run(apply));assert receipt['decisions_written']==4 and receipt['financial_effect']=='none'
assert run(finger)==finger_before
after=json.loads(run(init+queue));assert before['row_count']-after['row_count']==4
learned=next(x for x in after['rows'] if x['source_ref'].endswith('000000000051'))['suggestion']
assert learned['category']=='Bebidas' and learned['requires_confirmation'] is True and learned['beneficiary'] is None
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audits+4
assert run("SELECT bool_and(meta->>'actor'='assistant_under_owner_authorization' AND meta->'owner_confirmation'='false'::jsonb AND meta#>'{evidence,contract_identity_inferred}'='false'::jsonb AND meta#>'{evidence,coverage_current_inferred}'='false'::jsonb) FROM public.lts_access_audit WHERE action='apply_verified_card_nature_v316';")=='t'
assert json.loads(run(apply))['already_applied'] is True
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audits+4
assert run("SELECT bool_and(NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE')) FROM pg_proc WHERE proname IN('lts_card_verified_nature_candidates_v316','lts_apply_verified_card_natures_v316');")=='t'
run('SET ROLE authenticated;'+apply,False);run('SET ROLE anon;'+apply,False)
qa=ROOT/'qa/v316';qa.mkdir(parents=True,exist_ok=True)
for name,data in [('native-before.json',before),('native-after.json',after),('native-save.json',receipt)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',verified_natures=4,new_category_decisions_only=True,
 contract_and_coverage_not_inferred=True,explicit_preferences_and_people_preserved=True,
 unverified_or_inconsistent_sources_remain_pending=True,source_financial_rules_catalog_exact=True,
 learning_after_applied_nature=True,source_hash_and_replay_guards=True,client_roles_denied=True,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
