"""Animal-care natures without guessing an animal, product or specific service."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v317_ci.py'))
run,seed,U,OTHER,init=(base[k] for k in ['run','seed','U','OTHER','init'])
run((ROOT/'backend/patches/v318/verified_animal_care.sql').read_text())
run(f"INSERT INTO public.lts_category_catalog VALUES('{U}','Cuidados com animais',true);")
fixtures=[
 (91,'PETZ UNIDADE TESTE','5995','Pet supplies and vet'),(92,'IFD*COBASI COMERCIO DE','5995','Pet supplies and vet'),
 (93,'IFD*PET CENTER COMERCI','5995','Pet supplies and vet'),(94,'CENTRO VETERINARIO 1/2','742','Pet supplies and vet'),
 (95,'PETLOVE SAUD*Petlove S','6300','Insurance'),(96,'Vindi *RecreioDosBich','7299','Shopping'),
 (97,'PETZ UNIDADE TESTE',None,'Shopping'),(98,'PAYGO','5995','Pet supplies and vet'),
 (99,'Loja sem identidade','5995','Pet supplies and vet'),(100,'Vindi *Outra Empresa','7299','Shopping'),
 (101,'PETLOVE SAUD*Petlove S','6300','Insurance'),(102,'PETZ OUTRA UNIDADE','5995','Pet supplies and vet'),
 (103,'Vindi *RecreioDosBich','5968','Shopping'),(104,'PETZ ATUAL','5995','Pet supplies and vet')]
for n,desc,mcc,provider in fixtures:
 run(seed(n,desc,mcc)+f"UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{provider}') WHERE id='00000000-0000-4000-8000-{n:012d}';")
run(f"""INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,beneficiary,decision_basis)
 VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000101','Benjamin','explicit-person-only');
INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-pet-preference','PETZ OUTRA UNIDADE','Saúde',20,'2020-02-01','2020-01-01','1234',NULL);
UPDATE public.v312_rows SET reference_month=date_trunc('month',current_date)::date WHERE source_id='00000000-0000-4000-8000-000000000104';
UPDATE public.lts_open_finance_staging SET normalized_payload='{{"status":"PENDING"}}' WHERE id='00000000-0000-4000-8000-000000000096';""")
queue="SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,50,NULL);"
before=json.loads(run(init+queue));assert before['row_count']==len(before['rows'])
assert 'Cuidados com animais' in before['category_options']
qa=ROOT/'qa/v318';qa.mkdir(parents=True,exist_ok=True);(qa/'native-before.json').write_text(json.dumps(before,ensure_ascii=False))
targets=json.loads(run(f"SELECT public.lts_card_verified_nature_candidates_v318('{U}');"))
assert {int(x['source_ref'].split('-')[-1]) for x in targets}==set(range(91,97)),{x['source_ref']:x['category'] for x in targets}
assert all(t['category']=='Cuidados com animais' for t in targets)
for t in targets:
 assert all(t['evidence'][k] is False for k in ['specific_service_inferred','animal_identity_inferred','specific_product_inferred','personal_purpose_inferred','contract_identity_inferred','coverage_current_inferred','owner_confirmation','beneficiary_inferred','recurring_status_inferred','payment_or_realization_asserted'])
petlove=next(t for t in targets if t['source_ref'].endswith('000000000095'))
assert petlove['evidence']['replaced_bank_guess'] and petlove['evidence']['proposal_basis']=='bank_business_activity'
payload=json.dumps(targets,ensure_ascii=False).replace("'","''")
apply=f"SELECT public.lts_apply_verified_card_natures_v318('{U}','{payload}'::jsonb);"
for changed in [payload.replace('a'*64,'b'*64),payload.replace('Cuidados com animais','Saúde')]:
 run(f"SELECT public.lts_apply_verified_card_natures_v318('{U}','{changed}');",False)
run(f"SELECT public.lts_apply_verified_card_natures_v318('{OTHER}','{payload}');",False)
for mutation in [
 "UPDATE public.lts_category_catalog SET active=false WHERE category='Cuidados com animais';",
 f"INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-preserve-insurance-preference','PETLOVE SAUD*Petlove S','Seguros',20,'2020-02-01','2020-01-01','1234',NULL);",
 "UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{creditCardMetadata,payeeMCC}','\"5968\"') WHERE id='00000000-0000-4000-8000-000000000096';",
 f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000091','Saúde','explicit-override');"
]:run('BEGIN;'+mutation+apply+'ROLLBACK;',False)
finger="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s),'catalog',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s));"
fp=run(finger);audit_before=int(run('SELECT count(*) FROM public.lts_access_audit;'))
receipt=json.loads(run(apply));assert receipt['decisions_written']==6 and run(finger)==fp
after=json.loads(run(init+queue));assert before['row_count']-after['row_count']==6
learned=next(x for x in after['rows'] if x['source_ref'].endswith('000000000097'))['suggestion']
assert learned['category']=='Cuidados com animais' and learned['beneficiary'] is None and learned['requires_confirmation']
assert next(x for x in after['rows'] if x['source_ref'].endswith('000000000102'))['suggestion']['category']=='Saúde'
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+6
assert json.loads(run(apply))['already_applied'] and int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+6
assert run("SELECT bool_and(NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE')) FROM pg_proc WHERE proname IN('lts_card_verified_nature_candidates_v318','lts_apply_verified_card_natures_v318');")=='t'
run('SET ROLE authenticated;'+apply,False);run('SET ROLE anon;'+apply,False)
for name,data in [('native-after.json',after),('native-save.json',receipt)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',verified_natures=6,new_nature_available_and_learned=True,
 specific_business_can_replace_only_unconfirmed_bank_guess=True,explicit_history_and_people_preserved=True,
 no_animal_product_service_or_coverage_inferred=True,generic_intermediaries_and_wrong_codes_excluded=True,
 historical_pending_state_preserved=True,source_financial_rules_catalog_exact=True,hash_replay_cross_owner_and_client_guards=True,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
