"""Execute the real canonical reader and documentary guard; synthetic sources only."""
from pathlib import Path
import contextlib, io, runpy

R = Path(__file__).resolve().parents[2]

def generated(name):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        runpy.run_path(str(R / 'backend/qa' / name))
    return out.getvalue()

def source(path):
    return (R / path).read_text()

base = generated('lts_v343_ci_sql.py')
print(base[:base.rfind('ROLLBACK;')])
print('GRANT ALL ON public.lts_workbook_nonspend_source_v343 TO service_role;')
print(source('backend/patches/v348/salary_nonspend.sql'))
print(r'''
ALTER TABLE public.lts_reconciliation_evidence ALTER COLUMN id SET DEFAULT gen_random_uuid();
UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{m}','"sinal negativo"')WHERE idx=5;
CREATE TABLE public.lts_expense_effective_read_cache AS
SELECT user_id,source_table||':'||source_ref||':'||date_trunc('month',event_date)::date||':'||category_raw row_key,
event_date,event_date transaction_date,date_trunc('month',event_date)::date competence_month,amount,
category_raw category,NULL::text beneficiary,description_raw description,account_raw account_source,
source_table,source_ref,'direct_cash'::text coverage_mode,category_raw raw_category,NULL::text raw_reference,
NULL::date purchase_date,'identified'::text identity_status,category_raw management_group,
category_raw management_subgroup,NULL::text property_code,NULL::text property_component
FROM public.lts_expense_analytics_candidate;
CREATE TABLE public.lts_category_binding_v290(user_id uuid,raw_category text,category_key text);
CREATE TABLE public.lts_category_catalog(user_id uuid,category_key text,category text);
CREATE FUNCTION public.lts_expense_rows_pre_categories_v290(p_uid uuid,p_from date,p_to date)
RETURNS TABLE(row_key text,event_date date,transaction_date date,competence_month date,amount numeric,
category text,beneficiary text,description text,account_source text,source_table text,source_ref text,
coverage_mode text,raw_category text,raw_reference text,purchase_date date,identity_status text,
management_group text,management_subgroup text,property_code text,property_component text)
LANGUAGE sql STABLE SET search_path=''AS $fn$
SELECT c.row_key,c.event_date,c.transaction_date,c.competence_month,c.amount,c.category,c.beneficiary,
c.description,c.account_source,c.source_table,c.source_ref,c.coverage_mode,c.raw_category,c.raw_reference,
c.purchase_date,c.identity_status,c.management_group,c.management_subgroup,c.property_code,c.property_component
FROM public.lts_expense_effective_read_cache c WHERE c.user_id=p_uid AND c.event_date BETWEEN p_from AND p_to
$fn$;
''')
print(source('backend/qa/fixtures/v354_canonical_original.sql') + ';')
print(r'''
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows(uuid,date,date)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date)TO service_role;
CREATE TEMP TABLE v354_before AS SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)j
FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2013-10-10',current_date)r;
''')
patch = source('backend/patches/v354/read_documented_adjustment.sql')
activation = source('backend/patches/v354/activate_documented_adjustment.sql')
print(patch)
print(r'''
DO $test$BEGIN
IF(SELECT j FROM v354_before)IS DISTINCT FROM(SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)
FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2013-10-10',current_date)r)
THEN RAISE EXCEPTION 'Reader changed without documentary activation';END IF;
END$test$;
''')
# Reuse the two-source proof fixture, not the former physical-cache mutation.
old = source('backend/qa/lts_v348_ci_sql.py')
proof = old[old.index("SELECT set_config('lts.v348_owner'", old.index('# Also rerun')):
            old.index('CREATE TEMP TABLE v348_income_cases')]
print(proof.replace('lts.v348_', 'lts.v354_'))
print(r'''
SELECT set_config('lts.v354_income_proof',jsonb_set(current_setting('lts.v354_income_proof')::jsonb,
'{user_id}',to_jsonb('00000000-0000-4000-8000-000000000001'::uuid))::text,true);
CREATE TEMP TABLE v354_sql(kind text,sql text);
CREATE TEMP TABLE v354_cases(name text,mutation text);
''')
print("INSERT INTO v354_sql VALUES('activation',$qa$" + activation + "$qa$),('patch',$qa$" + patch + '$qa$);')
print(r'''
INSERT INTO v354_cases
SELECT path,'SELECT set_config(''lts.v354_income_proof'',jsonb_set(current_setting(''lts.v354_income_proof'')::jsonb,'||quote_literal(path)||','||quote_literal(value::text)||'::jsonb)::text,true)'
FROM(VALUES
 ('{metadata,flow_label_cell}','"A44"'::jsonb),('{metadata,nature}','"receipt"'),
 ('{metadata,workbook_signed_amount}','50'),('{metadata,source_payload}','{}'),
 ('{metadata,workbook_rows}','[105,106]'),('{metadata,workbook_evidence,0,signed_amount}','50'),
 ('{metadata,workbook_evidence,1,sha256}','"wrong"'),('{metadata,workbook_evidence,1,row}','999'),
 ('{metadata,workbook_evidence,1,date}','"2015-06-01"'),
 ('{metadata,workbook_evidence,1,file}','"Controle_Financeiro_v16.xlsm"'),
 ('{metadata,workbook_evidence,0,description}','"salary"'))x(path,value);
INSERT INTO v354_cases VALUES
('raw source changed',$q$UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{h}','"changed"')WHERE idx=5$q$),
('cached amount changed',$q$UPDATE public.lts_expense_effective_read_cache SET amount=51 WHERE source_ref='5'$q$),
('duplicate membership',$q$INSERT INTO public.lts_expense_effective_read_cache SELECT*FROM public.lts_expense_effective_read_cache WHERE source_ref='5'$q$),
('later explicit decision',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','historico_analitico','5','Later')$q$),
('wrong owner',$q$SELECT set_config('lts.v354_owner','00000000-0000-4000-8000-000000000002',true)$q$);
DO $test$DECLARE r record;m text;BEGIN FOR r IN SELECT*FROM v354_cases LOOP BEGIN
EXECUTE r.mutation;m:=NULL;
BEGIN EXECUTE(SELECT sql FROM v354_sql WHERE kind='activation');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
IF m IS NULL OR m NOT LIKE'V354_%'THEN RAISE EXCEPTION 'Invalid proof accepted: % / %',r.name,m;END IF;
RAISE EXCEPTION USING ERRCODE='V3540',MESSAGE='rollback fixture';
EXCEPTION WHEN SQLSTATE'V3540'THEN NULL;END;END LOOP;END$test$;
''')
print(activation)
print(r'''
DO $test$DECLARE m text;BEGIN
IF(current_setting('lts.v354_income_receipt')::jsonb->>'delta')::numeric<>-50
OR current_setting('lts.v354_income_receipt')::jsonb->>'physical_cache_preserved'<>'true'
THEN RAISE EXCEPTION 'Wrong documentary receipt';END IF;
IF(SELECT count(*)FROM public.lts_workbook_nonspend_source_v343)<>5
OR(SELECT count(*)FROM public.lts_expense_effective_read_cache)<>10
OR(SELECT count(*)FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000002','2013-10-10',current_date))<>5
THEN RAISE EXCEPTION 'Existing proofs, cache or other owner changed';END IF;
BEGIN EXECUTE(SELECT sql FROM v354_sql WHERE kind='activation');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
IF m IS DISTINCT FROM'V354_INCOME_EXISTING_EVIDENCE'THEN RAISE EXCEPTION 'Activation replay accepted';END IF;
m:=NULL;BEGIN EXECUTE(SELECT sql FROM v354_sql WHERE kind='patch');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
IF m IS DISTINCT FROM'V354_CANONICAL_SOURCE_CHANGED'THEN RAISE EXCEPTION 'Source lease replay accepted';END IF;
END$test$;
CREATE TEMP TABLE v354_revalidation(name text,mutation text,expected integer);
INSERT INTO v354_revalidation VALUES
('later decision',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','historico_analitico','5','Later')$q$,1),
('raw changed',$q$UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{h}','"changed"')WHERE idx=5$q$,1),
('different date',$q$UPDATE public.lts_expense_effective_read_cache SET event_date='2015-05-02'WHERE source_ref='5'$q$,1),
('different amount',$q$UPDATE public.lts_expense_effective_read_cache SET amount=51 WHERE source_ref='5'$q$,1),
('different coverage',$q$UPDATE public.lts_expense_effective_read_cache SET coverage_mode='card_observed_posted'WHERE source_ref='5'$q$,1),
('duplicate cached occurrence',$q$INSERT INTO public.lts_expense_effective_read_cache SELECT*FROM public.lts_expense_effective_read_cache WHERE source_ref='5'$q$,2),
('conflicting evidence',$q$INSERT INTO public.lts_reconciliation_evidence SELECT gen_random_uuid(),user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata FROM public.lts_reconciliation_evidence WHERE source_ref='historico_analitico:5'$q$,1),
('revoked proof',$q$UPDATE public.lts_reconciliation_evidence SET status='pending'WHERE source_ref='historico_analitico:5'$q$,1),
('changed workbook hash',$q$UPDATE public.lts_reconciliation_evidence SET metadata=jsonb_set(metadata,'{workbook_evidence,1,sha256}','"changed"')WHERE source_ref='historico_analitico:5'$q$,1);
DO $test$DECLARE r record;BEGIN FOR r IN SELECT*FROM v354_revalidation LOOP BEGIN
EXECUTE r.mutation;
IF(SELECT count(*)FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2013-10-10',current_date)WHERE source_ref='5')<>r.expected
THEN RAISE EXCEPTION 'Invalid documentary exclusion retained: %',r.name;END IF;
RAISE EXCEPTION USING ERRCODE='V3540',MESSAGE='rollback revalidation';
EXCEPTION WHEN SQLSTATE'V3540'THEN NULL;END;END LOOP;
EXECUTE'SET LOCAL ROLE authenticated';
BEGIN PERFORM*FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2013-10-10',current_date);RAISE EXCEPTION 'Private helper exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
EXECUTE'RESET ROLE';END$test$;
SELECT jsonb_build_object('pass',true,'version',354,'invalid_activation_cases',(SELECT count(*)FROM v354_cases),
'read_revalidation_cases',(SELECT count(*)FROM v354_revalidation),'raw_and_physical_cache_preserved',true,
'exact_documentary_exclusion',true,'source_lease_preserved',true,'private_access_denied',true,'owner_isolation',true,'replay_rejected',true);
ROLLBACK;
''')
