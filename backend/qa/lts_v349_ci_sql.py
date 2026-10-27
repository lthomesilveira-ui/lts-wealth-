"""Clock-change regression in native PostgreSQL, synthetic contracts only."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2]
patch=(R/'backend/patches/v349/c6_series_clock.sql').read_text()
fixture=(R/'backend/qa/fixtures/v349_cycles_before.sql').read_text()
cols='source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,amount numeric,description text,category text,category_basis text,installment_number integer,total_installments integer,is_payment boolean,bill_id text,observed_at timestamptz'
items=[]
for i in range(1,6):
    ts='2024-01-04T12:00:00+00:00'if i<=2 else'2024-01-04T15:00:00+00:00'
    items.append(dict(source_id=f'10000000-0000-4000-8000-{i:012d}',bank='C6',family='c6',card_name='Synthetic C6',last4='1234',billing_last4='5678',posting_date=f'2024-{i+1:02d}-01',purchase_date='2024-01-04',reference_month=f'2024-{i+1:02d}-01',due_date=f'2024-{i+1:02d}-05',provider_status='DOCUMENTED'if i==5 else'POSTED',amount=10.03 if i==1 else 10,description='Synthetic purchase',category='Synthetic category',category_basis='source',installment_number=i,total_installments=7,is_payment=False,bill_id=None,observed_at='2024-06-01T00:00:00Z',contract_key=json.dumps(['336','synthetic-account','1234',ts,'syntheticpurchase',7]),cycle_offset=2024*12+1))
payload=json.dumps(items)
print('BEGIN;')
print(fixture+';')
print(patch)
print("CREATE TEMP TABLE v349_original(payload jsonb);INSERT INTO v349_original VALUES($data$"+payload+"$data$);")
print(r'''
DO $test$DECLARE a jsonb;b jsonb;BEGIN
 SELECT payload INTO a FROM v349_original;b:=public.lts_c6_contract_clock_rows_v349(a);
 IF(SELECT count(DISTINCT r->>'contract_key')FROM jsonb_array_elements(b)r)<>1 THEN RAISE EXCEPTION 'Clock chain not bridged';END IF;
 IF EXISTS((SELECT r-'contract_key'FROM jsonb_array_elements(a)r EXCEPT ALL SELECT r-'contract_key'FROM jsonb_array_elements(b)r)
 UNION ALL(SELECT r-'contract_key'FROM jsonb_array_elements(b)r EXCEPT ALL SELECT r-'contract_key'FROM jsonb_array_elements(a)r))THEN RAISE EXCEPTION 'Financial source attributes changed';END IF;
END$test$;
CREATE TEMP TABLE v349_cases(name text,mutation text);
INSERT INTO v349_cases VALUES
 ('no documentary anchor',$q$SELECT jsonb_agg(CASE WHEN r->>'provider_status'='DOCUMENTED'THEN jsonb_set(r,'{provider_status}','"POSTED"')ELSE r END)FROM jsonb_array_elements($1)r$q$),
 ('two-hour gap',$q$SELECT jsonb_agg(CASE WHEN(r->>'installment_number')::int>=3 THEN jsonb_set(r,'{contract_key}',to_jsonb(jsonb_set((r->>'contract_key')::jsonb,'{3}','"2024-01-04T14:00:00+00:00"')::text))ELSE r END)FROM jsonb_array_elements($1)r$q$),
 ('duplicate installment',$q$SELECT jsonb_set($1,'{4,installment_number}','2')$q$),
 ('different cycle offset',$q$SELECT jsonb_set($1,'{4,cycle_offset}','1')$q$),
 ('incompatible amounts',$q$SELECT jsonb_set($1,'{4,amount}','20')$q$),
 ('single old observation',$q$SELECT $1-0$q$),
 ('wrong civil date',$q$SELECT jsonb_agg(jsonb_set(r,'{purchase_date}','"2024-01-03"'))FROM jsonb_array_elements($1)r$q$);
INSERT INTO v349_cases SELECT label,
 'SELECT jsonb_agg(CASE WHEN(r->>''installment_number'')::int>=3 THEN jsonb_set(r,''{contract_key}'',to_jsonb(jsonb_set((r->>''contract_key'')::jsonb,'||quote_literal('{'||slot||'}')||','||quote_literal(value::text)||'::jsonb)::text))ELSE r END)FROM jsonb_array_elements($1)r'
 FROM(VALUES('different institution',0,'"999"'::jsonb),('different account',1,'"other-account"'),('different card',2,'"9999"'),('different merchant',4,'"othermerchant"'),('different plan',5,'8'))x(label,slot,value);
DO $test$DECLARE c record;a jsonb;m jsonb;b jsonb;BEGIN
 SELECT payload INTO a FROM v349_original;
 FOR c IN SELECT * FROM v349_cases LOOP
 EXECUTE c.mutation INTO m USING a;b:=public.lts_c6_contract_clock_rows_v349(m);
 IF EXISTS((SELECT r FROM jsonb_array_elements(m)r EXCEPT ALL SELECT r FROM jsonb_array_elements(b)r)
 UNION ALL(SELECT r FROM jsonb_array_elements(b)r EXCEPT ALL SELECT r FROM jsonb_array_elements(m)r))THEN RAISE EXCEPTION 'Ambiguous chain modified: %',c.name;END IF;
 END LOOP;
 EXECUTE 'SET LOCAL ROLE authenticated';
 BEGIN PERFORM public.lts_c6_contract_clock_rows_v349('[]');RAISE EXCEPTION 'Private helper exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
END$test$;
''')
# Compile and execute the actual changed contract/projection CTEs, with source stubs.
print("CREATE TABLE public.v349_rows(user_id uuid,payload jsonb);INSERT INTO public.v349_rows SELECT '00000000-0000-4000-8000-000000000001',payload FROM v349_original;")
print('CREATE FUNCTION public.lts_card_source_rows_v226(p_uid uuid)RETURNS TABLE('+cols+")LANGUAGE sql AS $$SELECT r.*FROM public.v349_rows b CROSS JOIN LATERAL jsonb_to_recordset(b.payload)r("+cols+')WHERE b.user_id=p_uid$$;')
print(r'''
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,institution_code text,provider_account_ref text,raw_payload jsonb,normalized_payload jsonb);
INSERT INTO public.lts_open_finance_staging SELECT(r->>'source_id')::uuid,user_id,'card_transaction','336','synthetic-account',jsonb_build_object('creditCardMetadata',jsonb_build_object('purchaseDate',((r->>'contract_key')::jsonb)->>3,'installmentNumber',(r->>'installment_number')::int,'totalInstallments',7,'cardNumber','1234')),'{}'FROM public.v349_rows CROSS JOIN LATERAL jsonb_array_elements(payload)r WHERE r->>'provider_status'<>'DOCUMENTED';
CREATE TABLE public.lts_card_document_supplement_v234(id uuid,user_id uuid,metadata jsonb,installment_number integer,total_installments integer,last4 text,purchase_date date);
INSERT INTO public.lts_card_document_supplement_v234 VALUES('10000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','{"prior_purchase_source_id":"10000000-0000-4000-8000-000000000004"}',5,7,'1234','2024-01-04');
CREATE FUNCTION public.lts_card_merchant_key_v226(text)RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT replace(lower($1),' ','')$$;
CREATE TEMP TABLE v349_projection_queries(kind text,sql text);
''')
def projection_query(s,start):
    a=s.index(start);b=s.index('\naccounts as materialized',a)
    core=s[a:b].strip().rstrip(',')
    return "WITH rows AS MATERIALIZED(SELECT * FROM public.lts_card_source_rows_v226($1)),"+core.replace('p_user_id','$1')+" SELECT to_jsonb(r) row FROM c6_projection_sources r"
print("INSERT INTO v349_projection_queries VALUES('before',$qa$"+projection_query(fixture,'c6_contract_rows AS MATERIALIZED (')+"$qa$);")
print(r'''
DO $test$DECLARE s text;a int;b int;u uuid:='00000000-0000-4000-8000-000000000001';BEGIN
 SELECT pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure)INTO s;
 s:=substring(s FROM position('c6_contract_rows_raw_v349 AS MATERIALIZED ('IN s));
 s:=substring(s FOR position(E'\naccounts as materialized'IN s)-1);s:=regexp_replace(s,',[[:space:]]*$','');
 s:='WITH rows AS MATERIALIZED(SELECT * FROM public.lts_card_source_rows_v226($1)),'||replace(s,'p_user_id','$1')||' SELECT to_jsonb(r) row FROM c6_projection_sources r';
 INSERT INTO v349_projection_queries VALUES('after',s);
 EXECUTE 'CREATE TEMP TABLE v349_projection_before AS '||(SELECT sql FROM v349_projection_queries WHERE kind='before')USING u;
 EXECUTE 'CREATE TEMP TABLE v349_projection_after AS '||s USING u;
 SELECT count(*)INTO a FROM v349_projection_before;SELECT count(*)INTO b FROM v349_projection_after;
 IF a<>7 OR b<>2 THEN RAISE EXCEPTION 'Wrong projection coverage: % -> %',a,b;END IF;
 EXECUTE 'CREATE TEMP TABLE v349_other_owner AS '||s USING '00000000-0000-4000-8000-000000000002'::uuid;
 IF EXISTS(SELECT 1 FROM v349_other_owner)THEN RAISE EXCEPTION 'Cross-owner rows';END IF;
END$test$;
''')
print(patch)
print(r'''
SELECT jsonb_build_object('pass',true,'version',349,'rejection_cases',(SELECT count(*)FROM v349_cases),'projection_before',7,'projection_after',2,'amounts_dates_categories_preserved',true,'owner_isolation',true,'private_access_denied',true,'replay_noop',true);
ROLLBACK;
''')
