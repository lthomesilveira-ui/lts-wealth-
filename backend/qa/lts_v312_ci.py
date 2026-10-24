"""Native, source-backed classification learning with synthetic financial records."""
from pathlib import Path
import json,subprocess

ROOT=Path(__file__).resolve().parents[2]
U='00000000-0000-4000-8000-000000000001';OTHER='00000000-0000-4000-8000-000000000099'
def run(sql,success=True):
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 if success and r.returncode:raise RuntimeError(r.stderr)
 if not success and not r.returncode:raise AssertionError('Expected a guarded rejection')
 return r.stdout.strip()
schema=r"""
CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('sub',auth.uid(),'email','fixture@example.invalid')$$;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql STABLE AS $$BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required';END IF;RETURN auth.uid();END$$;
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower(trim(coalesce($1,'')))$$;
CREATE FUNCTION public.lts_card_merchant_key_v226(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT regexp_replace(regexp_replace(lower($1),'[0-9]{1,2}/[0-9]{1,2}$','','g'),'[^a-z0-9]','','g')$$;
CREATE FUNCTION public.lts_bank_merchant_key_v231(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT public.lts_card_merchant_key_v226($1)$$;
CREATE FUNCTION public.lts_category_name_v290(uuid,text) RETURNS text LANGUAGE sql STABLE AS $$SELECT nullif(regexp_replace(trim($2),'^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–][[:space:]]*',''),'')$$;
CREATE TABLE public.lts_category_catalog(user_id uuid,category text,active boolean);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,provider_deleted_at timestamptz,
 currency text,description_raw text,posting_date date,signed_amount numeric,raw_hash text,raw_payload jsonb,normalized_payload jsonb,created_at timestamptz);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text,beneficiary text,
 property_code text,decision_basis text,decided_at timestamptz DEFAULT now(),PRIMARY KEY(user_id,source_table,source_ref));
CREATE TABLE public.lts_access_audit(user_id uuid,email text,action text,meta jsonb);
CREATE TABLE public.lts_card_document_supplement_v234(user_id uuid,id uuid);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,line_key text,description_raw text,category text,installment_amount numeric,invoice_due_date date,purchase_date date,card_final text,installments int);
CREATE TABLE public.financial_events(user_id uuid,id uuid,description_raw text,category text,amount numeric,event_date date,metadata jsonb,is_suppressed boolean,is_projection boolean);
CREATE TABLE public.lts_document_card_purchase(user_id uuid,id uuid,description text,category text,amount numeric,purchase_date date,metadata jsonb,cost_center text,status text);
CREATE TABLE public.lts_manual_card_purchase(LIKE public.lts_document_card_purchase);
CREATE TABLE public.lts_card_history_recovered_purchase(user_id uuid,source_hash text,description_raw text,canonical_category text,category_raw text,amount numeric,invoice_due_date date,card_final text,evidence jsonb);
CREATE TABLE public.card_invoices(user_id uuid,id uuid,metadata jsonb,due_date date);
CREATE TABLE public.historico_analitico(usuario_id uuid,idx int,dados jsonb);
CREATE TABLE public.lts_semantic_rule(user_id uuid,id text,category text,center_cost text,match_type text,match_value text,confidence text,active boolean);
CREATE TABLE public.lts_v229_review_suggestion(user_id uuid,source_table text,source_ref text,category text,basis text,note text,source_url text);
CREATE TABLE public.lts_merchant_research_v231(user_id uuid,merchant_key text,category text,note text,source_url text);
CREATE TABLE public.v312_rows(user_id uuid,source_id uuid,bank text,card_name text,family text,last4 text,purchase_date date,posting_date date,
 reference_month date,installment_number int,total_installments int,is_payment boolean,amount numeric,description text,category text,category_basis text);
CREATE TABLE public.v312_expense_review(user_id uuid,source_table text,source_ref text,identity_status text);
CREATE FUNCTION public.lts_v229_review_rows(uuid,date,date) RETURNS TABLE(source_table text,source_ref text,identity_status text) LANGUAGE sql STABLE AS $$SELECT source_table,source_ref,identity_status FROM public.v312_expense_review WHERE user_id=$1$$;
CREATE FUNCTION public.lts_card_source_rows_v226(uuid) RETURNS TABLE(source_id uuid,bank text,card_name text,family text,last4 text,purchase_date date,posting_date date,reference_month date,installment_number int,total_installments int,is_payment boolean,amount numeric,description text,category text,category_basis text)
 LANGUAGE sql STABLE AS $$SELECT r.source_id,r.bank,r.card_name,r.family,r.last4,r.purchase_date,r.posting_date,r.reference_month,r.installment_number,r.total_installments,r.is_payment,r.amount,r.description,
 coalesce(d.category_label,r.category),CASE WHEN d.category_label IS NOT NULL THEN 'user_decision' ELSE r.category_basis END
 FROM public.v312_rows r LEFT JOIN public.lts_v178_review_decision d ON d.user_id=r.user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=r.source_id::text WHERE r.user_id=$1$$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
GRANT EXECUTE ON FUNCTION auth.uid(),auth.jwt() TO authenticated,anon;
"""
run(schema+(ROOT/'backend/qa/v312_existing_classifiers.sql').read_text()+(ROOT/'backend/patches/v312/card_review.sql').read_text())
run(f"INSERT INTO public.lts_category_catalog SELECT '{U}',c,true FROM unnest(ARRAY['Farmácia','Saúde','Vestuário','Restaurantes','Educação','Seguros','Batizado','Casa'])c;")
def seed(n,desc,mcc=None,user=U,deleted=False,payment=False,amount=20,known=False):
 uid=f'00000000-0000-4000-8000-{n:012d}'
 return f"""INSERT INTO public.lts_open_finance_staging VALUES('{uid}','{user}','card_transaction',{'now()' if deleted else 'NULL'},'BRL','{desc}','2020-01-01',-{amount},repeat('a',64),jsonb_build_object('creditCardMetadata',jsonb_build_object('payeeMCC',{'NULL' if mcc is None else chr(39)+mcc+chr(39)},'cardNumber','1234','purchaseDate','2020-01-01T12:00:00Z')),jsonb_build_object('status','POSTED'),now());
INSERT INTO public.v312_rows VALUES('{user}','{uid}','Bradesco','Visa Aeternum','aeternum','1234','2020-01-01','2020-01-01','2020-01-01',NULL,NULL,{str(payment).lower()},{amount},'{desc}',{chr(39)+('Casa' if known else 'A classificar')+chr(39)},'{('known' if known else 'unresolved')}');"""
run(seed(1,'Farmácia de teste','5912')+seed(2,'Farmácia de teste','5912')+seed(3,'AMAZON TESTE','5912')+seed(4,'PIX pessoa fictícia','5812')+seed(5,'Compra sem pista')+seed(6,'Loja histórica de teste','5651')+seed(7,'Já identificada',known=True)+seed(8,'Outro proprietário','5912',OTHER)+seed(9,'Removida','5912',deleted=True)+seed(10,'Pagamento de fatura','5912',payment=True)+seed(11,'Crédito de teste','5912',amount=-4)+seed(12,'Compra com versão','5912')+seed(13,'Histórico conflitante','5912')+seed(15,'Loja com pessoa na origem','5651'))
run(f"""INSERT INTO public.lts_semantic_rule VALUES('{U}','fixture-marketplace','Batizado',NULL,'exact','AMAZON TESTE','user_confirmed',true);
INSERT INTO public.financial_events VALUES('{U}','00000000-0000-4000-8000-000000000501','Histórico conflitante','Saúde',20,'2020-01-01','{{}}',false,false),('{U}','00000000-0000-4000-8000-000000000502','Histórico conflitante','Vestuário',20,'2020-01-01','{{}}',false,false);
INSERT INTO public.lts_card_purchase_detail VALUES('{U}','fixture-prefixed','Loja com pessoa na origem','Larissa — Vestuário',20,'2020-02-01','2020-01-01','1234',NULL);""")
init=f"SET request.jwt.claim.sub='{U}';SET ROLE authenticated;"
queue="SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,10,NULL);"
before=json.loads(run(init+queue));assert before['row_count']==9 and before['additional_count']==9
by_id={int(r['source_ref'].split('-')[-1]):r for r in before['rows']}
assert by_id[1]['suggestion']['category']=='Farmácia'
assert by_id[3]['suggestion']['category'] is None and by_id[3]['suggestion']['basis']=='platform_purchase_needs_context'
assert by_id[4]['suggestion']['category'] is None
assert by_id[5]['suggestion']['category'] is None
assert by_id[13]['suggestion']['basis']=='conflicting_history' and by_id[13]['suggestion']['category'] is None
assert by_id[15]['suggestion']['category']=='Vestuário' and by_id[15]['suggestion']['beneficiary'] is None
assert all(r['suggestion']['requires_confirmation'] and r['suggestion']['beneficiary'] is None for r in before['rows'])
assert run('SELECT count(*) FROM public.lts_v178_review_decision;')=='0'
assert run(init+"SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,2,'Farmácia')->>'matched_count';")=='2'
assert run(init+"SELECT jsonb_array_length(public.lts_browser_card_review_queue_v312('2013-10-10',current_date,-2,500,NULL)->'rows');")=='9'
assert run(init+"SELECT public.lts_browser_card_review_queue_v312('2013-10-10',current_date,0,2,NULL)->>'next_offset';")=='2'
assert run(f"SET request.jwt.claim.sub='{OTHER}';SET ROLE authenticated;"+queue).find('Outro proprietário')>=0
assert run("SET ROLE anon;"+queue,False)==''
run("SET ROLE authenticated;"+queue,False)
for args in ["NULL,current_date,0,10,NULL","'2026-01-02','2026-01-01',0,10,NULL","'2012-01-01',current_date,0,10,NULL"]:run(init+'SELECT public.lts_browser_card_review_queue_v312('+args+');',False)
save=lambda n,cat='Farmácia',hash="repeat('a',64)",person='NULL':f"SELECT public.lts_browser_card_review_save_v312('00000000-0000-4000-8000-{n:012d}',{hash},'{cat}',{person});"
for statement in [save(8),save(9),save(10),save(11),save(12,hash="repeat('b',64)"),save(12,cat='Desconhecida'),save(12,person="'Pessoa inventada'")]:run(init+statement,False)
fingerprint="SELECT jsonb_build_object('sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s));"
source_before=run(fingerprint);receipt=json.loads(run(init+save(1)));assert receipt['ok']
after=json.loads(run(init+queue));assert after['row_count']==8
learned=next(r for r in after['rows'] if r['source_ref'].endswith('000000000002'))
assert learned['suggestion']['category']=='Farmácia' and learned['suggestion']['basis']=='same_merchant_amount_history'
assert run(fingerprint)==source_before
audit=run('SELECT count(*) FROM public.lts_access_audit;');assert json.loads(run(init+save(1)))['already_classified']
assert audit==run('SELECT count(*) FROM public.lts_access_audit;')
run(init+save(1,cat='Saúde'),False)
run(init+"SELECT public.lts_browser_card_classify_v226('00000000-0000-4000-8000-000000000001','Saúde',NULL);")
corrected=json.loads(run(init+queue));assert next(r for r in corrected['rows'] if r['source_ref'].endswith('000000000002'))['suggestion']['category']=='Saúde'
assert run(fingerprint)==source_before
assert run(f"BEGIN;UPDATE public.lts_category_catalog SET active=false WHERE category='Farmácia';{init}"+save(12)+'ROLLBACK;',False)==''
assert run("SELECT bool_and(NOT prosecdef AND NOT has_function_privilege('authenticated',oid,'EXECUTE') AND NOT has_function_privilege('anon',oid,'EXECUTE')) FROM pg_proc WHERE proname IN('lts_card_pending_sources_v312','lts_card_activity_category_v312','lts_card_review_suggestions_v312');")=='t'
qa=ROOT/'qa/v312';qa.mkdir(parents=True,exist_ok=True)
(qa/'native-before.json').write_text(json.dumps(before));(qa/'native-after.json').write_text(json.dumps(after));(qa/'native-save.json').write_text(json.dumps(receipt))
print(json.dumps({'pass':True,'engine':'postgresql17','historical_gap_visible':True,'pending_before':9,'pending_after':8,'suggestions_do_not_write':True,
 'learns_from_confirmation':True,'learns_from_correction':True,'marketplace_suppressed':True,'conflicting_history_preserved':True,
 'funding_not_assigned_restaurant':True,'no_person_inferred':True,'raw_and_financial_rows_exact':True,'source_hash_checked':True,
 'no_duplicate_write_on_replay':True,'cross_owner_anon_and_stale_or_invalid_writes_rejected':True,'production_data_used':False}))
