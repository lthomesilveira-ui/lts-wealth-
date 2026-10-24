"""Native PostgreSQL fixture for forecast evidence and all reader leases."""
from pathlib import Path
import json,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
U='00000000-0000-4000-8000-000000000001'
def run(sql,success=True):
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 if success and r.returncode:raise RuntimeError(r.stderr)
 if not success and not r.returncode:raise AssertionError('Expected guarded rejection')
 return r.stdout.strip()

schema="""
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
SET timezone='America/Sao_Paulo'; SET check_function_bodies=false;
CREATE TABLE public.card_invoices(id uuid,user_id uuid,legacy_id text,card_name text,billing_account_id text,
 reference_month date,due_date date,status text,amount numeric,source text,metadata jsonb,created_at timestamptz);
CREATE TABLE public.lts_card_due_rule_v290(user_id uuid,family text,effective_from date,due_day int);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,
 currency text,institution_code text,provider_account_ref text,normalized_payload jsonb,raw_payload jsonb);
CREATE TABLE public.v311_rows(user_id uuid,source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,
 posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,amount numeric,description text,
 category text,category_basis text,installment_number int,total_installments int,is_payment boolean,bill_id text,observed_at timestamptz);
CREATE TABLE public.v311_bills(user_id uuid,invoice_source_id uuid,family text,card_name text,last4 text,reference_month date,
 due_date date,amount numeric,payment_status text,reported_payment_amount numeric,source_updated_at timestamptz,received_at timestamptz);
CREATE FUNCTION public.lts_card_source_rows_v226(uuid) RETURNS TABLE(source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,
 posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,amount numeric,description text,
 category text,category_basis text,installment_number int,total_installments int,is_payment boolean,bill_id text,observed_at timestamptz)
 LANGUAGE sql STABLE AS $$SELECT source_id,bank,family,card_name,last4,billing_last4,posting_date,purchase_date,reference_month,due_date,
 provider_status,amount,description,category,category_basis,installment_number,total_installments,is_payment,bill_id,observed_at FROM public.v311_rows WHERE user_id=$1$$;
CREATE FUNCTION public.lts_current_received_card_bills_v263(uuid) RETURNS TABLE(invoice_source_id uuid,family text,card_name text,last4 text,reference_month date,
 due_date date,amount numeric,payment_status text,reported_payment_amount numeric,source_updated_at timestamptz,received_at timestamptz)
 LANGUAGE sql STABLE AS $$SELECT invoice_source_id,family,card_name,last4,reference_month,due_date,amount,payment_status,reported_payment_amount,source_updated_at,received_at FROM public.v311_bills WHERE user_id=$1$$;
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT CASE WHEN $1 ilike '%Aeternum%' THEN 'aeternum' WHEN $1 ilike '%C6%' THEN 'c6' ELSE 'itau_mastercard' END$$;
CREATE FUNCTION public.lts_card_merchant_key_v226(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT regexp_replace(lower($1),'[^a-z0-9]','','g')$$;
"""
run(schema)
definitions=json.loads((ROOT/'backend/qa/v311_prior_reader_definitions.json').read_text())
run('SET check_function_bodies=false;'+''.join(x['definition']+';' for x in definitions.values()))
patch=subprocess.check_output([sys.executable,str(ROOT/'backend/tools/build_card_forecast_patch_v311.py')],input=json.dumps(definitions),text=True)
attrs="SELECT jsonb_agg(to_jsonb(p)-ARRAY['prosrc','probin'] ORDER BY proname) FROM pg_proc p WHERE proname IN('lts_card_cycles_v226','lts_card_projection_rows_v290','lts_card_projected_invoice_records_v290','lts_card_invoices_effective_v226');"
before=run(attrs);run('BEGIN;SET check_function_bodies=false;'+patch+'COMMIT;');assert before==run(attrs)
run("""CREATE FUNCTION public.lts_card_invoice_amounts_v230(uuid) RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text) LANGUAGE sql AS $$
SELECT * FROM public.lts_card_projection_rows_v290($1) UNION ALL
SELECT i.user_id,i.card_name,i.reference_month,i.due_date,i.status,i.amount,i.source FROM public.card_invoices i WHERE i.user_id=$1
AND NOT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290($1)p WHERE p.reference_month=i.reference_month AND public.lts_card_family_v226(p.card_name,p.card_name)=public.lts_card_family_v226(i.card_name,i.card_name))$$;""")
run(f"""
INSERT INTO lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000100','{U}','invoice',NULL,'BRL','237','fixture-account','{{"provider_id":"fixture-bill"}}','{{}}');
INSERT INTO v311_bills VALUES('{U}','00000000-0000-4000-8000-000000000100','aeternum','Visa Aeternum','1234',date_trunc('month',current_date),date_trunc('month',current_date)::date+24,200,'payment_not_reported',0,now(),now());
INSERT INTO card_invoices VALUES('00000000-0000-4000-8000-000000000200','{U}','fixture-current','Visa Aeternum','fixture-account',date_trunc('month',current_date),date_trunc('month',current_date)::date+24,'open',200,'fixture','{{}}',now());
INSERT INTO card_invoices SELECT '00000000-0000-4000-8000-000000000201','{U}','fixture-future','Visa Aeternum','fixture-account',(date_trunc('month',current_date)+interval '1 month')::date,(date_trunc('month',current_date)+interval '1 month')::date+24,'projected',1,'old-snapshot','{{}}',now();
""")
def seed(identifier,amount,number=None,total=None,months=0,purchase='2020-02-01',status='POSTED',bill='fixture-bill',payment=False,card='1234'):
 uid=f'00000000-0000-4000-8000-{identifier:012d}'
 return f"""
INSERT INTO v311_rows VALUES('{U}','{uid}','Bradesco','aeternum','Visa Aeternum','{card}','1234',current_date,'{purchase}',
(date_trunc('month',current_date)+make_interval(months=>{months}))::date,NULL,'{status}',{amount},'Fixture purchase','Casa','fixture',
{number if number is not None else 'NULL'},{total if total is not None else 'NULL'},{str(payment).lower()},{'NULL' if bill is None else "'"+bill+"'"},now());
INSERT INTO lts_open_finance_staging VALUES('{uid}','{U}','card_transaction',NULL,'BRL','237','fixture-account','{{}}',
jsonb_build_object('creditCardMetadata',jsonb_build_object('purchaseDate','{purchase}T12:00:00Z')));
"""
run(seed(1,80,2,4)+seed(2,20,1,3,purchase='2020-03-01')+seed(3,100)+seed(4,30,1,2,1,'2020-04-01','PENDING',None)+seed(5,40,months=1,status='PENDING',bill=None)+seed(6,-5,months=1,status='PENDING',bill=None)+seed(7,500,months=1,status='PENDING',bill=None,payment=True))
select=f"SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY reference_month),'[]') FROM public.lts_aeternum_forecast_cycles_v311('{U}')r;"
def check(mutation,expected):
 value=json.loads(run('BEGIN;'+mutation+select+'ROLLBACK;'))
 assert [float(x['amount']) for x in value]==expected,(expected,value)
 for x in value:assert round(sum(float(i['amount']) for i in x['items']),2)==float(x['amount'])
 return value
cycles=check('',[165,130]);check(seed(8,80,3,4,1,'2020-02-01','PENDING',None),[165,130])
check(seed(9,80,1,2,1,'2020-06-01','PENDING',None),[245,210])
check(seed(10,999,months=0,status='PENDING'),[165,130])
check("UPDATE lts_open_finance_staging SET currency='USD' WHERE id='00000000-0000-4000-8000-000000000004';",[135,100])
check("UPDATE lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000004';",[135,100])
check("UPDATE lts_open_finance_staging SET provider_account_ref='other-account' WHERE resource_type='invoice';",[])
check("UPDATE v311_bills SET amount=201;",[])
check("UPDATE lts_open_finance_staging SET raw_payload='{}' WHERE id='00000000-0000-4000-8000-000000000001';",[])
check("UPDATE v311_rows SET total_installments=2147483647 WHERE source_id='00000000-0000-4000-8000-000000000001';",[])
assert json.loads(run(select.replace(U,'00000000-0000-4000-8000-000000000099')))==[]
# Exact future official cycle replaces, and is never combined with, its projection.
value=json.loads(run(f"BEGIN;INSERT INTO lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000101','{U}','invoice',NULL,'BRL','237','fixture-account','{{\"provider_id\":\"next-fixture-bill\"}}','{{}}');INSERT INTO v311_bills SELECT user_id,'00000000-0000-4000-8000-000000000101',family,card_name,last4,(reference_month+interval '1 month')::date,(due_date+interval '1 month')::date,165,payment_status,0,now(),now() FROM v311_bills;"+select+'ROLLBACK;'));assert value==[],value
effective=json.loads(run(f"SELECT jsonb_agg(jsonb_build_object('amount',amount,'items',metadata->'items')) FROM lts_card_invoices_effective_v226('{U}') WHERE reference_month>date_trunc('month',current_date)::date;"))
assert sorted(float(x['amount']) for x in effective)==[130,165]
for row in effective:assert round(sum(float(x['amount']) for x in row['items']),2)==float(row['amount'])
native=run(f"""SELECT public.lts_card_forecast_overlay_v311('{U}',jsonb_build_object('version','card-cycles-v226','as_of',current_date,'complete',true,
'active_billing_accounts',2,'cards',jsonb_build_array(jsonb_build_object('family','aeternum','bank','Bradesco','name','Visa Aeternum','last4','1234','cycles',jsonb_build_array(
jsonb_build_object('month',date_trunc('month',current_date)::date,'due_date',date_trunc('month',current_date)::date+24,'amount',200,'basis','open_finance_invoice_v263','items','[]'::jsonb))),
jsonb_build_object('family','itau_mastercard','bank','Itaú','name','Mastercard','last4','4321','cycles','[]'::jsonb))));""")
payload=json.loads(native);assert len(payload['cards'][0]['cycles'])==3 and payload['cards'][1]['cycles']==[]
assert payload['cards'][0]['cycles'][1]['official_invoice_received'] is False
assert len(payload['cards'][0]['cycles'][1]['items'])==5
digest=run("SELECT md5(string_agg(pg_get_functiondef(oid),'|' ORDER BY proname)) FROM pg_proc WHERE proname IN('lts_card_cycles_v226','lts_card_projection_rows_v290','lts_card_projected_invoice_records_v290','lts_card_invoices_effective_v226') OR proname LIKE '%v311';")
run('BEGIN;SET check_function_bodies=false;'+patch+'COMMIT;')
assert digest==run("SELECT md5(string_agg(pg_get_functiondef(oid),'|' ORDER BY proname)) FROM pg_proc WHERE proname IN('lts_card_cycles_v226','lts_card_projection_rows_v290','lts_card_projected_invoice_records_v290','lts_card_invoices_effective_v226') OR proname LIKE '%v311';")
for name in definitions:
 run('BEGIN;'+definitions[name]['definition'].replace('AS $function$','AS $function$\n-- drift\n',1)+';'+patch,False)
run("BEGIN;CREATE OR REPLACE FUNCTION public.lts_card_forecast_overlay_v311(p_user_id uuid,p_payload jsonb) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT p_payload$$;"+patch,False)
assert run("SELECT bool_and(NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE') AND NOT prosecdef) FROM pg_proc WHERE proname IN('lts_aeternum_forecast_cycles_v311','lts_card_forecast_overlay_v311');")=='t'
qa=ROOT/'qa/v311';qa.mkdir(parents=True,exist_ok=True);(qa/'native-cycles.json').write_text(native)
print(json.dumps({'pass':True,'engine':'postgresql17','forecast_cases':12,'all_effective_item_totals_match':True,'provider_future_not_duplicated':True,
 'one_offs_not_repeated':True,'credits_net_once':True,'official_invoice_precedence':True,'source_owner_account_currency_and_deletion_checked':True,
 'four_existing_reader_attributes_exact':True,'exact_replay':True,'drift_rejections':5,'helpers_private':True,'production_data_used':False}))
