"""Coherent merchant natures and bank-category conflict guards."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v316_ci.py'))
run,seed,U,OTHER,init=(base[k] for k in ['run','seed','U','OTHER','init'])
patch='\n'.join((ROOT/'backend/patches/v317'/n).read_text() for n in ['activity_guard.sql','suggestion_guard.sql','verified_card_natures.sql'])
run(patch);run((ROOT/'backend/patches/v317/suggestion_guard.sql').read_text())
run(f"INSERT INTO public.lts_category_catalog SELECT '{U}',c,true FROM unnest(ARRAY['Alimentação e Bebidas','Combustível','Aluguel Carro','Rappi','Hotel','Passagem Aérea','Lazer'])c;")
fixtures=[
 (61,'PUKET','5651','Clothing'),(62,'ANACAPRI SHOPPING 1/2','5661','Clothing'),(63,'RAIA9997','5912','Pharmacy'),
 (64,'FINI - ABRIU SORRIU','5441','Groceries'),(65,'MAKE A CAKE','5462','Groceries'),(66,'SHELL','5541','Gas stations'),
 (67,'LOCALIZABRRAC','7512','Car rental'),(68,'ASSIST CARD DO BRASIL','6300','Insurance'),
 (69,'RAPPI*Rappi Brasil Int','4215','Food delivery'),(70,'BRADESCO VID*Parc','6300','Insurance'),
 (71,'HOTEL FAZ D CAROLINA','7011','Accomodation'),(72,'B BACHIR LTDA','5499','Groceries'),
 (73,'SMART FIT UNIDADE TESTE','7997','Wellness and fitness'),(74,'LATAM AIR*ABCDEF','3248','Airport and airlines'),
 (75,'AZUL LINHAS AEREA','3300','Airport and airlines'),
 (76,'Aquario de teste','5812','Cinema, theater and concerts'),(77,'Brigaderia de teste','5814','Stadiums and arenas'),
 (78,'Grupo de teste','5812','Gas stations'),(79,'Astor de teste','5812','Transfers'),
 (80,'Aquario com historico','5812','Cinema, theater and concerts'),
 (81,'LATAM AIR*GHIJKL','3247','Airport and airlines'),(82,'SMART FIT UNIDADE TESTE','7997','Shopping'),
 (83,'PUKET','5651','Clothing'),(84,'LATAM AIR*MNOPQR','3248','Airport and airlines'),(85,'Outra companhia','3300','Airport and airlines'),(86,'SMART FIT UNIDADE TESTE','7997','Wellness and fitness')]
for n,desc,mcc,provider in fixtures:
 run(seed(n,desc,mcc)+f"UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{provider}') WHERE id='00000000-0000-4000-8000-{n:012d}';")
run(f"""INSERT INTO public.lts_card_purchase_detail VALUES
('{U}','fixture-puket-preference','PUKET','Vestuário',20,'2020-02-01','2020-01-01','1234',NULL),
('{U}','fixture-raia-health-preference','RAIA9997','Saúde',20,'2020-02-01','2020-01-01','1234',NULL),
('{U}','fixture-rappi-preference','RAPPI*Rappi Brasil Int','Rappi',20,'2020-02-01','2020-01-01','1234',NULL),
('{U}','fixture-aquarium-preference','Aquario com historico','Lazer',20,'2020-02-01','2020-01-01','1234',NULL);
INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,beneficiary,decision_basis)
 VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000083','Benjamin','explicit-person-only');
UPDATE public.lts_open_finance_staging SET normalized_payload='{{"status":"PENDING"}}' WHERE id IN('00000000-0000-4000-8000-000000000073','00000000-0000-4000-8000-000000000086');
UPDATE public.v312_rows SET reference_month=date_trunc('month',current_date)::date WHERE source_id='00000000-0000-4000-8000-000000000086';
UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||'{{"operationType":"PIX"}}' WHERE id='00000000-0000-4000-8000-000000000084';""")
queue="SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,50,NULL);"
before=json.loads(run(init+queue));assert before['row_count']==len(before['rows'])
rows={int(x['source_ref'].split('-')[-1]):x for x in before['rows']}
for n in [76,77,78,79]:assert rows[n]['suggestion']['category'] is None and rows[n]['suggestion']['basis']=='bank_activity_conflict'
assert rows[80]['suggestion']['category']=='Lazer' and rows[80]['suggestion']['basis']=='merchant_history'
targets=json.loads(run(f"SELECT public.lts_card_verified_nature_candidates_v317('{U}');"))
assert {int(x['source_ref'].split('-')[-1]) for x in targets}==set(range(61,76))|{26}
assert next(x for x in targets if x['source_ref'].endswith('000000000063'))['category']=='Saúde'
for n in [73,74,75]:
 e=next(x for x in targets if x['source_ref'].endswith(f'{n:012d}'))['evidence']
 assert e['missing_activity_map'] and e['proposal_basis']=='insufficient_evidence'
for t in targets:
 assert all(t['evidence'][k] is False for k in ['specific_product_inferred','personal_purpose_inferred','contract_identity_inferred','coverage_current_inferred','owner_confirmation','beneficiary_inferred','recurring_status_inferred','payment_or_realization_asserted'])
assert next(x for x in targets if x['source_ref'].endswith('000000000073'))['evidence']['bank_source_status']=='PENDING'
payload=json.dumps(targets,ensure_ascii=False).replace("'","''")
apply=f"SELECT public.lts_apply_verified_card_natures_v317('{U}','{payload}'::jsonb);"
for changed in [payload.replace('a'*64,'b'*64),payload.replace('Passagem Aérea','Casa'),payload.replace('latam-airfare','unknown-rule')]:
 run(f"SELECT public.lts_apply_verified_card_natures_v317('{U}','{changed}');",False)
run(f"SELECT public.lts_apply_verified_card_natures_v317('{OTHER}','{payload}');",False)
for mutation in [
 "UPDATE public.lts_category_catalog SET active=false WHERE category='Saúde';",
 "UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||'{\"operationType\":\"PIX\"}' WHERE id='00000000-0000-4000-8000-000000000074';",
 "UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{creditCardMetadata,payeeMCC}','\"3247\"') WHERE id='00000000-0000-4000-8000-000000000074';",
 f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000061','Casa','explicit-override');"
]:run('BEGIN;'+mutation+apply+'ROLLBACK;',False)
finger="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s),'catalog',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s));"
fp=run(finger);audit_before=int(run('SELECT count(*) FROM public.lts_access_audit;'))
receipt=json.loads(run(apply));assert receipt['decisions_written']==16
assert run(finger)==fp
after=json.loads(run(init+queue));assert before['row_count']-after['row_count']==16
assert int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+16
assert json.loads(run(apply))['already_applied'] and int(run('SELECT count(*) FROM public.lts_access_audit;'))==audit_before+16
assert run("SELECT bool_and(NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE')) FROM pg_proc WHERE proname IN('lts_card_activity_guard_v317','lts_card_verified_nature_candidates_v317','lts_apply_verified_card_natures_v317');")=='t'
run('SET ROLE authenticated;'+apply,False);run('SET ROLE anon;'+apply,False)
qa=ROOT/'qa/v317';qa.mkdir(parents=True,exist_ok=True)
for name,data in [('native-before.json',before),('native-after.json',after),('native-save.json',receipt)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',verified_natures=16,conflicting_provider_activity_suppressed=True,
 explicit_history_precedence_preserved=True,pharmacy_health_preference_respected=True,
 exact_airline_mcc_and_provider_required=True,unmapped_activity_allowed_only_for_verified_merchants=True,
 no_product_clinical_person_property_or_contract_inference=True,pending_bank_state_preserved_without_realization=True,source_financial_rules_catalog_exact=True,
 hash_replay_cross_owner_and_existing_choice_guards=True,client_roles_denied=True,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
