"""Verified broad merchant natures, explicit provenance and conservative suggestions."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v312_ci.py'));run=base['run'];seed=base['seed'];U=base['U'];OTHER=base['OTHER'];init=base['init']
patch='\n'.join((ROOT/'backend/patches/v315'/n).read_text() for n in ['verified_card_natures.sql','suggestion_guard.sql'])
run(patch)
for n,desc,mcc,category in [(21,'RAIA9001','5912','Pharmacy'),(22,'Qualidoc *APP','5912','Pharmacy'),(23,'FLEURY UNIDADE TESTE','8071','Healthcare'),
 (24,'CARTPANDA*LOJA TESTE','5651','Clothing'),(25,'Medicamentos de teste','8299','School'),(26,'RAIA9998','5912','Pharmacy'),
 (27,'Farmácia desconhecida','5912','Pharmacy'),(31,'PG *FARMACIA TESTE','5912','Pharmacy'),(35,'RAIA9001',None,'Shopping')]:
 run(seed(n,desc,mcc)+f"UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{category}') WHERE id='00000000-0000-4000-8000-{n:012d}';")
run(f"""INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-raia-override','RAIA9998','Saúde',20,'2020-02-01','2020-01-01','1234',NULL);
UPDATE public.v312_rows SET installment_number=1,total_installments=3 WHERE source_id='00000000-0000-4000-8000-000000000031';
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,totalInstallments}}','3') WHERE id='00000000-0000-4000-8000-000000000031';
INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-same-purchase','PG *FARMACIA TESTE 2/3','Farmácia',20,'2020-02-01','2020-01-01','1234',3);""")
queue="SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,50,NULL);"
before=json.loads(run(init+queue));rows={int(x['source_ref'].split('-')[-1]):x for x in before['rows']}
assert rows[24]['suggestion']['category'] is None and rows[24]['suggestion']['basis']=='platform_purchase_needs_context'
assert rows[25]['suggestion']['category'] is None and rows[25]['suggestion']['basis']=='bank_activity_conflict'
assert rows[26]['suggestion']['category']=='Saúde'
assert rows[31]['suggestion']['category']=='Farmácia' and rows[31]['suggestion']['basis']=='same_purchase_installments'
assert rows[35]['suggestion']['category'] is None
targets=json.loads(run(f"SELECT public.lts_card_verified_nature_candidates_v315('{U}');"));assert len(targets)==3
assert {int(x['source_ref'].split('-')[-1]) for x in targets}=={21,22,23}
assert all(x['evidence']['owner_confirmation'] is False and x['evidence']['beneficiary_inferred'] is False for x in targets)
payload=json.dumps(targets,ensure_ascii=False).replace("'","''")
apply=f"SELECT public.lts_apply_verified_card_natures_v315('{U}','{payload}'::jsonb);"
audit_before=int(run("SELECT count(*) FROM public.lts_access_audit;"))
for changed in [payload.replace('a'*64,'b'*64),payload.replace('Farmácia','Vestuário')]:
 run(f"SELECT public.lts_apply_verified_card_natures_v315('{U}','{changed}');",False)
run(f"SELECT public.lts_apply_verified_card_natures_v315('{OTHER}','{payload}');",False)
run(f"SELECT public.lts_apply_verified_card_natures_v315('{U}','[]');",False)
duplicate=json.dumps([targets[0],targets[0]],ensure_ascii=False)
run(f"SELECT public.lts_apply_verified_card_natures_v315('{U}','{duplicate}');",False)
for change in [
 "UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000021';",
 "UPDATE public.lts_open_finance_staging SET currency='USD' WHERE id='00000000-0000-4000-8000-000000000021';",
 "UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{category}','\"Clothing\"') WHERE id='00000000-0000-4000-8000-000000000021';",
 "UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{type}','\"CREDIT\"') WHERE id='00000000-0000-4000-8000-000000000021';",
 "UPDATE public.lts_category_catalog SET active=false WHERE category='Farmácia';",
 f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000021',NULL,'Benjamin','explicit-person-only');"
]:run('BEGIN;'+change+apply+'ROLLBACK;',False)
finger="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s));"
fp=run(finger);receipt=json.loads(run(apply));assert receipt['decisions_written']==3
assert run(finger)==fp
after=json.loads(run(init+queue));assert before['row_count']-after['row_count']==3
learned=next(x for x in after['rows'] if x['source_ref'].endswith('000000000035'))
assert learned['suggestion']['category']=='Farmácia' and learned['suggestion']['requires_confirmation'] is True
assert learned['suggestion']['beneficiary'] is None
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+3
assert json.loads(run(apply))['already_applied'] is True
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+3
assert run("SELECT bool_and(NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE')) FROM pg_proc WHERE proname IN('lts_card_identity_guard_v315','lts_card_verified_nature_candidates_v315','lts_apply_verified_card_natures_v315');")=='t'
run('SET ROLE authenticated;'+apply,False);run('SET ROLE anon;'+apply,False)
qa=ROOT/'qa/v315';qa.mkdir(parents=True,exist_ok=True)
for name,data in [('native-before.json',before),('native-after.json',after),('native-save.json',receipt)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',verified_natures=3,source_financial_rules_exact=True,learns_after_verified_nature=True,
 no_person_or_recurring_inference=True,intermediary_and_conflicting_activity_proposals_suppressed=True,
 same_purchase_and_explicit_history_preserved=True,invalid_or_stale_writes_rejected=True,replay_audits_once=True,client_roles_denied=True,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
