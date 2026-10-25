"""Learn named supplier context while requiring purpose for unrelated funding."""
from pathlib import Path
import json,runpy,subprocess
ROOT=Path(__file__).resolve().parents[2]
base=runpy.run_path(str(ROOT/'backend/qa/lts_v319_ci.py'))
run,seed,U,OTHER,init=(base[k] for k in ['run','seed','U','OTHER','init'])
qa=ROOT/'qa/v327';qa.mkdir(parents=True,exist_ok=True)
run(f"INSERT INTO public.lts_category_catalog VALUES('{U}','Higiene e cuidados pessoais',true);")
run('CREATE TABLE public.source_documents(id uuid,metadata jsonb);')
def add(n,desc,mcc,amount,day,provider='Clothing',operation='PAGAMENTO',installment=None):
 uid=f'00000000-0000-4000-8000-{n:012d}'
 s=seed(n,desc,mcc,amount=amount)+f"""UPDATE public.lts_open_finance_staging SET posting_date='{day}',raw_payload=raw_payload||jsonb_build_object('type','DEBIT','category','{provider}','operationType','{operation}') WHERE id='{uid}';
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,purchaseDate}}','\"{day}T12:00:00Z\"') WHERE id='{uid}';
UPDATE public.v312_rows SET purchase_date='{day}',posting_date='{day}',reference_month=date_trunc('month','{day}'::date)::date WHERE source_id='{uid}';"""
 if installment:
  s+=f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,totalInstallments}}','3') WHERE id='{uid}';UPDATE public.v312_rows SET installment_number={installment},total_installments=3 WHERE source_id='{uid}';"
 run(s)
known=[(210,211,'EC *MOOSEBABYKIDS','5611','Clothing','Vestuário',80,90),
 (212,213,'EC *ALPHACO','5611','Clothing','Vestuário',40,50),
 (214,215,'PG *SLEEPO MODAS','5698','Clothing','Vestuário',70,80),
 (216,217,'PG *BOOMA ORGANIC COSM BRASILIA BRA','5122','Pharmacy','Higiene e cuidados pessoais',25,30)]
for a,b,desc,mcc,provider,category,old_amount,new_amount in known:
 add(a,desc,mcc,old_amount,'2022-01-01',provider)
 add(b,desc,mcc,new_amount,'2022-02-01',provider)
 person="'Benjamin'" if a==210 else 'NULL'
 run(init+f"SELECT public.lts_browser_card_classify_v226('00000000-0000-4000-8000-{a:012d}','{category}',{person});")
add(220,'EC *MOOSEBABYKIDS','5611',100,'2022-03-01',operation='PIX')
add(221,'EC *MOOSEBABYKIDS','5812',101,'2022-03-01',provider='Restaurants')
add(222,'EC *MOOSEBABYKIDS EXTRA','5611',102,'2022-03-01')
add(223,'EC *LOJA NAO IDENTIFICADA','5611',103,'2022-03-01')
add(224,'AMAZON SEM PRODUTO','5611',104,'2022-03-01')
add(225,'Fornecedor conhecido de teste','5651',45,'2022-03-01',operation='PIX')
add(226,'PG *LOJA NAO IDENTIFICADA','5611',20,'2022-01-01',installment=2)
add(227,'PIX PLANO CONFIRMADO','5611',21,'2022-01-01',operation='PIX',installment=2)
add(228,'EC *ALPHACO','5611',51,'2022-03-01',provider='Healthcare')
run(f"""INSERT INTO public.lts_card_purchase_detail VALUES
('{U}','fixture-funding-history','Fornecedor conhecido de teste','Vestuário',45,'2020-02-01','2020-01-01','1234',NULL),
('{U}','fixture-strong-unknown-supplier','PG *LOJA NAO IDENTIFICADA 1/3','Vestuário',20,'2022-02-01','2022-01-01','1234',3),
('{U}','fixture-strong-funding-purpose','PIX PLANO CONFIRMADO 1/3','Vestuário',21,'2022-02-01','2022-01-01','1234',3);""")
queue="SELECT public.lts_browser_card_review_queue_v312('2022-01-01','2022-12-31',0,50,NULL);"
def index(data):return{int(x['source_ref'].split('-')[-1]):x['suggestion'] for x in data['rows']}
before=json.loads(run(init+queue));old=index(before)
assert before['row_count']==13
assert all(old[n]['category'] is None and old[n]['basis']=='platform_purchase_needs_context' for n in(211,213,215,217))
assert old[225]['category']=='Vestuário','Original funding-history defect not reproduced'
assert old[226]['basis']==old[227]['basis']=='same_purchase_installments'
finger="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),'decisions',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,source_table,source_ref)::text) FROM public.lts_v178_review_decision s),'catalog',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s),'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s));"
frozen=run(finger);attrs="SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_card_review_suggestions_v312(uuid,jsonb)'::regprocedure;"
attributes=run(attrs);patch=(ROOT/'backend/patches/v327/suggestion_learning.sql').read_text()
unaffected_targets=run(f"SELECT jsonb_agg(p.item) FROM public.lts_card_pending_sources_v312('{U}')p JOIN public.lts_open_finance_staging s ON s.id::text=p.item->>'source_ref' WHERE (p.item->>'event_date')::date<'2022-01-01' AND coalesce(s.raw_payload->>'operationType','') NOT IN('PIX','TED','TRANSFER','SAQUE') AND public.lts_v178_norm(p.item->>'description')!~'^(pix|transferencia|saque)([^a-z]|$)';")
unaffected_query=f"SELECT jsonb_agg(to_jsonb(r) ORDER BY source_ref) FROM public.lts_card_review_suggestions_v312('{U}','{unaffected_targets.replace(chr(39),chr(39)*2)}')r;"
unaffected_before=run(unaffected_query)
run(patch);after=json.loads(run(init+queue));new=index(after)
assert after['row_count']==before['row_count'] and run(finger)==frozen and run(attrs)==attributes
for n,category in [(211,'Vestuário'),(213,'Vestuário'),(215,'Vestuário'),(217,'Higiene e cuidados pessoais')]:
 assert new[n]['category']==category and new[n]['basis']=='merchant_history',new[n]
for n in(220,225):assert new[n]['category'] is None and new[n]['basis']=='funding_purpose_needs_context',new[n]
for n in(221,222,223,224,228):assert new[n]['category'] is None and new[n]['basis']=='platform_purchase_needs_context',new[n]
assert new[226]==old[226] and new[227]==old[227]
assert run(unaffected_query)==unaffected_before
assert all(s['beneficiary'] is None and s['property_code'] is None and s['requires_confirmation'] for s in new.values())
corrected=json.loads(run('BEGIN;'+init+"DO $$BEGIN PERFORM public.lts_browser_card_classify_v226('00000000-0000-4000-8000-000000000210','Saúde','Benjamin');END$$;"+queue+'ROLLBACK;'))
assert index(corrected)[211]['category']=='Saúde' and index(corrected)[211]['beneficiary'] is None
assert run(finger)==frozen
run(patch)
stable=lambda d:{k:v for k,v in d.items() if k!='checked_at'}
assert stable(json.loads(run(init+queue)))==stable(after) and run(attrs)==attributes
signature='public.lts_card_named_supplier_v327(text,text,text)'
assert run(f"SELECT NOT prosecdef AND provolatile='i' AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE oid='{signature}'::regprocedure;")=='t'
assert run("SELECT public.lts_card_named_supplier_v327(' EC  *MOOSEBABYKIDS ','5611','Clothing') AND NOT public.lts_card_named_supplier_v327('EC *MOOSEBABYKIDS','5611','Healthcare') AND NOT public.lts_card_named_supplier_v327('EC *MOOSE','5611','Clothing') AND NOT public.lts_card_named_supplier_v327('CARTPANDA*MINIMAL','5611','Clothing');")=='t'
for role in('anon','authenticated'):run(f"SET ROLE {role};SELECT public.lts_card_named_supplier_v327('EC *ALPHACO','5611','Clothing');",False)
prior=(ROOT/'backend/qa/v327_prior_reader.sql').read_text()
def reject_lease(sql,message):
 p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 assert p.returncode and message in p.stderr,p.stderr
reject_lease('BEGIN;'+prior.replace('AS $function$','AS $function$\n-- drift\n',1)+';\n'+patch+'ROLLBACK;','Suggestion definition changed')
reject_lease("BEGIN;ALTER FUNCTION public.lts_card_named_supplier_v327(text,text,text) SET search_path=public;"+patch+'ROLLBACK;','Named supplier helper changed')
assert run(finger)==frozen
targets=json.dumps(after['rows'],ensure_ascii=False).replace("'","''")
assert run(f"SELECT count(*) FROM public.lts_card_review_suggestions_v312('{OTHER}','{targets}'::jsonb);")=='0'
plan=json.loads(run(f"EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT *FROM public.lts_card_review_suggestions_v312('{U}','{targets}'::jsonb);"))
for name,data in [('native-before.json',before),('native-after.json',after),('plan-after.json',plan)]:
 (qa/name).write_text(json.dumps(data,ensure_ascii=False))
result=dict(passed=True,engine='postgresql17',known_named_suppliers_learn_from_history=True,
 old_funding_history_defect_reproduced=True,unrelated_funding_requires_own_purpose=True,
 exact_same_purchase_purpose_preserved=True,wrong_code_provider_and_extended_or_generic_names_rejected=True,
 marketplace_context_requirement_preserved=True,owner_correction_is_learned_without_person_copy=True,
 suggestions_do_not_write_classifications=True,source_and_financial_rows_exact=True,
 unaffected_nonfunding_suggestions_exact=True,
 function_attributes_private_acl_replay_and_drift_guarded=True,explain_analyze_recorded=True,
 production_performance_benchmark=False,production_data_used=False)
(qa/'native-result.json').write_text(json.dumps(result));print(json.dumps(result))
