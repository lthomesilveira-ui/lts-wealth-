"""User corrections outrank derived merchant natures at equivalent evidence strength."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v318_ci.py'))
run,seed,U,OTHER,init=(base[k] for k in ['run','seed','U','OTHER','init'])
patch=(ROOT/'backend/patches/v319/correction_precedence.sql').read_text()
# pg_get_functiondef fixtures omit ACLs; reproduce the observed production grants.
run("REVOKE ALL ON FUNCTION public.lts_review_suggestions_v231(uuid,jsonb) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.lts_review_suggestions_v231(uuid,jsonb) TO service_role;")
qa=ROOT/'qa/v319';qa.mkdir(parents=True,exist_ok=True)
cases=[(151,'PETZ APRENDIZADO',20,1),(152,'PETZ APRENDIZADO',20.02,2),(153,'PETZ APRENDIZADO',20.02,3),
 (161,'PETZ CORRECAO',30,None),(162,'PETZ CORRECAO',30,None),(163,'PETZ CORRECAO',30,None),
 (171,'PETZ FORCA',40,None),(172,'PETZ FORCA',40,None)]
for n,desc,amount,installment in cases:
 mcc=None if n in(153,163,172) else '5995'
 provider='Shopping' if mcc is None else 'Pet supplies and vet'
 run(seed(n,desc,mcc,amount=amount)+f"""UPDATE public.lts_open_finance_staging SET posting_date='2021-01-01',
 raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{provider}') WHERE id='00000000-0000-4000-8000-{n:012d}';
 UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,purchaseDate}}','\"2021-01-01T12:00:00Z\"') WHERE id='00000000-0000-4000-8000-{n:012d}';
 UPDATE public.v312_rows SET purchase_date='2021-01-01',posting_date='2021-01-01',reference_month='2021-01-01' WHERE source_id='00000000-0000-4000-8000-{n:012d}';""")
 if installment:
  run(f"""UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,totalInstallments}}','3') WHERE id='00000000-0000-4000-8000-{n:012d}';
  UPDATE public.v312_rows SET installment_number={installment},total_installments=3 WHERE source_id='00000000-0000-4000-8000-{n:012d}';""")
run(f"INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-weaker-original-preference','PETZ FORCA','Saúde',400,'2020-02-01','2020-01-01','1234',NULL);")
targets=json.loads(run(f"SELECT public.lts_card_verified_nature_candidates_v318('{U}');"))
# The weaker original preference also blocks automatic application for that merchant.
# Seed its already-derived historical decision directly as controlled fixture data.
targets=[t for t in targets if int(t['source_ref'].split('-')[-1]) in(151,152,161,162)]
assert len(targets)==4
payload=json.dumps(targets,ensure_ascii=False).replace("'","''")
run(f"SELECT public.lts_apply_verified_card_natures_v318('{U}','{payload}');")
run(f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis) VALUES('{U}','lts_open_finance_staging','00000000-0000-4000-8000-000000000171','Cuidados com animais','verified_merchant_activity_v318:petz-care');")
queue="SELECT public.lts_browser_card_review_queue_v312('2021-01-01','2021-12-31',0,50,NULL);"
before=json.loads(run(init+queue));assert before['row_count']==3
assert all(x['suggestion']['category']=='Cuidados com animais' for x in before['rows'])
def correct(n,category,person='NULL'):
 return f"SELECT public.lts_browser_card_classify_v226('00000000-0000-4000-8000-{n:012d}','{category}',{person});"
run(init+correct(151,'Saúde',"'Rafiki'"));run(init+correct(161,'Saúde',"'Larissa'"))
legacy=json.loads(run(init+queue));old={int(x['source_ref'].split('-')[-1]):x['suggestion'] for x in legacy['rows']}
assert old[153]['category']=='Cuidados com animais',old
assert old[163]['category'] is None and old[163]['basis']=='conflicting_history',old
assert old[172]['category']=='Cuidados com animais',old
finger=base['finger'];source_before=run(finger)
definition=run("SELECT pg_get_functiondef('public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure);")
body=definition.split('AS $function$')[1].split('$function$')[0]
plan_targets=json.dumps([x for x in legacy['rows']],ensure_ascii=False).replace("'","''")
explain=lambda d:json.loads(run('EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) '+d.replace('p_user_id',f"'{U}'::uuid").replace('p_targets',f"'{plan_targets}'::jsonb")))
plan_before=explain(body)
nonauto=run(f"SELECT jsonb_agg(item) FROM public.lts_card_pending_sources_v312('{U}') WHERE item->>'source_ref' IN('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000013');")
noai_query=f"SELECT jsonb_agg(to_jsonb(x) ORDER BY source_ref) FROM public.lts_review_suggestions_v231('{U}','{nonauto}')x;"
noai_before=run(noai_query)
run(patch);assert run(finger)==source_before
after=json.loads(run(init+queue));rows={int(x['source_ref'].split('-')[-1]):x['suggestion'] for x in after['rows']}
assert rows[153]['category']=='Saúde' and rows[163]['category']=='Saúde',rows
assert rows[172]['category']=='Cuidados com animais',rows
assert all(x['beneficiary'] is None and x['property_code'] is None and x['requires_confirmation'] for x in rows.values())
assert run(noai_query)==noai_before
conflict=json.loads(run('BEGIN;'+init+'DO $c$ BEGIN PERFORM public.lts_browser_card_classify_v226(\'00000000-0000-4000-8000-000000000162\',\'Vestuário\',NULL);END $c$;'+queue+'ROLLBACK;'))
conflicting=next(x for x in conflict['rows'] if x['source_ref'].endswith('000000000163'))['suggestion']
assert conflicting['category'] is None and conflicting['basis']=='conflicting_history'
assert run(finger)==source_before
run(patch);assert run(finger)==source_before
assert json.loads(run(init+queue))['row_count']==3
new_definition=run("SELECT pg_get_functiondef('public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure);")
plan_after=explain(new_definition.split('AS $function$')[1].split('$function$')[0])
drift="CREATE OR REPLACE FUNCTION public.lts_review_suggestions_v231(p_user_id uuid,p_targets jsonb) RETURNS TABLE(source_table text,source_ref text,suggestion jsonb) LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $$SELECT NULL::text,NULL::text,NULL::jsonb WHERE false$$;"
run('BEGIN;'+drift+patch+'ROLLBACK;',False)
assert run(finger)==source_before
assert run("SELECT NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE oid='public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure;")=='t'
run(f"SET ROLE anon;SELECT * FROM public.lts_review_suggestions_v231('{U}','[]');",False)
run(f"SET ROLE authenticated;SELECT * FROM public.lts_review_suggestions_v231('{U}','[]');",False)
for name,data in [('native-before.json',before),('native-legacy-bug.json',legacy),('native-after.json',after),('plan-before.json',plan_before),('plan-after.json',plan_after)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',learns_owner_correction_over_automatic_nature=True,
 same_purchase_cent_difference_reuses_correction=True,equal_amount_automatic_conflict_resolved_by_original_correction=True,
 weaker_generic_preference_does_not_override_stronger_match=True,conflicting_original_choices_stay_pending=True,
 no_person_or_property_inferred=True,nonautomatic_behavior_exact=True,all_source_financial_and_decision_data_exact=True,
 function_attributes_replay_drift_and_roles_guarded=True,explain_analyze_recorded=True,production_performance_benchmark=False,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
