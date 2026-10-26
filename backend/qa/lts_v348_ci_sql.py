"""Native regression tests: source signs and salary vs spending. Synthetic only."""
from pathlib import Path
import contextlib, io, runpy
R=Path(__file__).resolve().parents[2]
def generated(name):
    s=io.StringIO()
    with contextlib.redirect_stdout(s):runpy.run_path(str(R/'backend/qa'/name))
    return s.getvalue()
activation=(R/'backend/patches/v348/activate_documented_signs.sql').read_text()
income=(R/'backend/patches/v348/activate_income_adjustment.sql').read_text()
salary=(R/'backend/patches/v348/salary_nonspend.sql').read_text()
# Retain the real pre-V347 identity wrapper and its independent native fixture.
print(generated('lts_v347_ci_sql.py').split('INSERT INTO public.evento_base SELECT')[0])
print("CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text);")
print((R/'backend/patches/v347/preserve_documented_identity.sql').read_text())
print(r'''
INSERT INTO public.evento_base SELECT '00000000-0000-4000-8000-000000000001',i,jsonb_build_object('dia','2024-01-01','desc','synthetic '||i,'valor',i*10,'efeito','saida','conta','Itaú')FROM generate_series(1,3)i;
INSERT INTO public.lts_expense_effective_read_cache SELECT usuario_id,date '2024-01-01',date '2024-01-01',date '2024-01-01',(dados->>'valor')::numeric,'Synthetic category',NULL,dados->>'desc','bank','Itaú','evento_base',idx::text,'direct_cash',false,false,now()FROM public.evento_base;
INSERT INTO public.lts_expense_effective_read_cache SELECT '00000000-0000-4000-8000-000000000002',event_date,transaction_date,competence_month,amount,category,center_cost,counterparty,origin_type,origin_name,source_table,source_ref,coverage_mode,is_property,is_financing,refreshed_at FROM public.lts_expense_effective_read_cache;
INSERT INTO public.lts_workbook_identity_evidence_v232 SELECT usuario_id,'evento_base',idx::text,date '2024-01-01',(dados->>'valor')::numeric,'Synthetic category',dados->>'desc'FROM public.evento_base;
SELECT set_config('lts.v348_owner','00000000-0000-4000-8000-000000000001',true);
SELECT set_config('lts.v348_proofs',(SELECT jsonb_agg(jsonb_build_object('source_table','evento_base','source_ref',idx::text,'row_key','evento_base:'||idx||':2024-01-01:Synthetic category','event_date','2024-01-01','description',dados->>'desc','source_category','Synthetic category','imported_amount',idx*10,'documented_signed_amount',-idx*10,'workbook_row',100+idx,'raw_payload',dados,
 'primary',jsonb_build_object('file','Controle_Financeiro_v16.xlsm','sha256','57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e','sheet','Pagamentos e Recebimentos','row',100+idx,'date','2024-01-01','description',dados->>'desc','category','Synthetic category','signed_amount',-idx*10),
 'secondary',jsonb_build_object('file','Controle_Financeiro_Fase1_Compactado.xlsx','sha256','36e26f4c168483680bfbb723934fb09165c5884b03de052cc07b39ded00ab086','sheet','Pagamentos e Recebimentos','row',100+idx,'date','2024-01-01','description',dados->>'desc','category','Synthetic category','signed_amount',-idx*10)))::text FROM public.evento_base WHERE idx<=2),true);
CREATE TEMP TABLE v348_sqls(kind text,sql text);
''')
print("INSERT INTO v348_sqls VALUES('signs',$qa$"+activation+"$qa$);")
print(r'''
CREATE TEMP TABLE v348_cases(name text,mutation text);
INSERT INTO v348_cases VALUES
 ('positive source',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,primary,signed_amount}','10')::text,true)$q$),
 ('case distinguishes original receipt',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,primary,description}','"Synthetic 1"')::text,true)$q$),
 ('signed mapping changed',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,documented_signed_amount}','-11')::text,true)$q$),
 ('wrong workbook row',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,workbook_row}','999')::text,true)$q$),
 ('valid format wrong hash',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,primary,sha256}',to_jsonb(repeat('a',64)))::text,true)$q$),
 ('second workbook differs',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,secondary,row}','999')::text,true)$q$),
 ('wrong date',$q$SELECT set_config('lts.v348_proofs',jsonb_set(current_setting('lts.v348_proofs')::jsonb,'{0,primary,date}','"2024-01-02"')::text,true)$q$),
 ('wrong owner',$q$SELECT set_config('lts.v348_owner','00000000-0000-4000-8000-000000000002',true)$q$),
 ('duplicate origin',$q$SELECT set_config('lts.v348_proofs',(current_setting('lts.v348_proofs')::jsonb||jsonb_build_array(current_setting('lts.v348_proofs')::jsonb->0))::text,true)$q$),
 ('raw source differs',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{conta}','"Other bank"')WHERE idx=1$q$),
 ('current membership differs',$q$UPDATE public.lts_expense_effective_read_cache SET amount=11 WHERE source_ref='1'AND user_id='00000000-0000-4000-8000-000000000001'$q$),
 ('later owner decision',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','1')$q$);
DO $test$DECLARE r record;m text;BEGIN FOR r IN SELECT * FROM v348_cases LOOP BEGIN
 EXECUTE r.mutation;m:=NULL;BEGIN EXECUTE(SELECT sql FROM v348_sqls WHERE kind='signs');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS NULL OR m NOT LIKE 'V348_%'THEN RAISE EXCEPTION 'Invalid proof accepted or unexpected rejection: % / %',r.name,m;END IF;
 RAISE EXCEPTION USING ERRCODE='V3480',MESSAGE='rollback case';EXCEPTION WHEN SQLSTATE 'V3480'THEN NULL;END;END LOOP;END$test$;
''')
print(activation)
print(r'''
DO $test$DECLARE receipt jsonb;m text;BEGIN receipt:=current_setting('lts.v348_receipt')::jsonb;
 IF(receipt->>'count')::int<>2 OR(receipt->>'delta')::numeric<>-60 OR(receipt->>'after_total')::numeric<>0 THEN RAISE EXCEPTION 'Wrong result';END IF;
 IF(SELECT sum(amount)FROM public.lts_expense_effective_read_cache WHERE user_id='00000000-0000-4000-8000-000000000002')<>60 THEN RAISE EXCEPTION 'Other owner changed';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2024-01-01','2024-01-31')WHERE identity_status<>'identified'OR management_group<>'Synthetic category')THEN RAISE EXCEPTION 'Identity changed';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_reconciliation_evidence)THEN RAISE EXCEPTION 'Cash proof invented';END IF;
 BEGIN EXECUTE(SELECT sql FROM v348_sqls WHERE kind='signs');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V348_EXISTING_OVERRIDE_REQUIRES_REVIEW'THEN RAISE EXCEPTION 'Replay not rejected';END IF;
END$test$;
SELECT jsonb_build_object('pass',true,'version',348,'part','signs','rejection_cases',(SELECT count(*)FROM v348_cases),'identity_preserved',true,'no_cash_evidence_created',true,'owner_isolation',true,'replay_rejected',true);
ROLLBACK;
''')
# Also rerun all existing V343 defenses, then add the salary-specific contract.
base=generated('lts_v343_ci_sql.py')
print(base[:base.rfind('ROLLBACK;')])
print("GRANT ALL ON public.lts_workbook_nonspend_source_v343 TO service_role;")
print(salary)
print(r'''
ALTER TABLE public.lts_reconciliation_evidence ALTER COLUMN id SET DEFAULT gen_random_uuid();
UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{m}','"sinal negativo"')WHERE idx=5;
CREATE TABLE public.lts_expense_effective_read_cache AS SELECT user_id,source_table,source_ref,event_date,amount,'direct_cash'::text coverage_mode FROM public.lts_expense_analytics_candidate;
CREATE FUNCTION public.lts_v229_expense_rows(p_uid uuid,p_from date,p_to date)RETURNS TABLE(row_key text,event_date date,amount numeric,source_table text,source_ref text)LANGUAGE sql AS $$SELECT c.source_table||':'||c.source_ref||':'||date_trunc('month',c.event_date)::date||':'||CASE WHEN source_ref='5'THEN 'Salário' ELSE 'Synthetic'END,c.event_date,c.amount,c.source_table,c.source_ref FROM public.lts_expense_effective_read_cache c WHERE c.user_id=p_uid AND c.event_date BETWEEN p_from AND p_to$$;
SELECT set_config('lts.v348_owner','00000000-0000-4000-8000-000000000001',true);
SELECT set_config('lts.v348_income_proof',(SELECT jsonb_build_object('source_table','historico_analitico','source_ref','5','row_key','historico_analitico:5:2015-05-01:Salário','event_date','2015-05-01','imported_amount',50,'documented_signed_amount',-50,'raw_payload',dados,'metadata',jsonb_build_object(
 'schema','workbook-nonspend-v343','batch','workbook-source-v348','source_table','historico_analitico','source_ref','5','source_payload',dados,'nature','receipt_adjustment','documented_direction','entrada','workbook_sheet','Pagamentos e Recebimentos','workbook_rows','[105]'::jsonb,'tuple_multiplicity',1,'flow_sheet','Fluxo de Caixa','flow_label_cell','A10','income_sum_row',7,'workbook_signed_amount',-50,'workbook_sha256','57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e',
 'workbook_evidence',jsonb_build_array(
 jsonb_build_object('file','Controle_Financeiro_v16.xlsm','sha256','57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e','sheet','Pagamentos e Recebimentos','row',105,'date','2015-05-01','description','Salário','category','Salário','signed_amount',-50),
 jsonb_build_object('file','Controle_Financeiro_Fase1_Compactado.xlsx','sha256','36e26f4c168483680bfbb723934fb09165c5884b03de052cc07b39ded00ab086','sheet','Pagamentos e Recebimentos','row',105,'date','2015-05-01','description','Salário','category','Salário','signed_amount',-50))))::text FROM public.historico_analitico WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND idx=5),true);
CREATE TEMP TABLE v348_income_cases(path text,value jsonb);
INSERT INTO v348_income_cases VALUES
 ('{metadata,flow_label_cell}','"A44"'),('{metadata,nature}','"receipt"'),('{metadata,workbook_signed_amount}','50'),
 ('{metadata,source_payload}','{}'),('{metadata,workbook_rows}','[105,106]'),('{metadata,workbook_evidence,0,signed_amount}','50'),
 ('{metadata,workbook_evidence,1,sha256}','"wrong"'),('{metadata,workbook_evidence,1,row}','999'),('{metadata,workbook_evidence,1,date}','"2015-06-01"'),
 ('{metadata,workbook_evidence,1,file}','"Controle_Financeiro_v16.xlsm"'),('{metadata,workbook_evidence,0,description}','"salary"');
CREATE TEMP TABLE v348_income_sql(sql text);
''')
print("INSERT INTO v348_income_sql VALUES($qa$"+income+"$qa$);")
print(r'''
DO $test$DECLARE r record;m text;BEGIN FOR r IN SELECT * FROM v348_income_cases LOOP BEGIN
 PERFORM set_config('lts.v348_income_proof',jsonb_set(current_setting('lts.v348_income_proof')::jsonb,r.path::text[],r.value)::text,true);
 m:=NULL;BEGIN EXECUTE(SELECT sql FROM v348_income_sql);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS NULL OR m NOT LIKE 'V348_%'THEN RAISE EXCEPTION 'Invalid income proof accepted: % / %',r.path,m;END IF;
 RAISE EXCEPTION USING ERRCODE='V3480',MESSAGE='rollback income case';EXCEPTION WHEN SQLSTATE 'V3480'THEN NULL;END;END LOOP;END$test$;
''')
print(income)
print(r'''
DO $test$DECLARE m text;BEGIN
 IF(current_setting('lts.v348_income_receipt')::jsonb->>'delta')::numeric<>-50 THEN RAISE EXCEPTION 'Wrong income delta';END IF;
 IF(SELECT count(*)FROM public.lts_workbook_nonspend_source_v343)<>5 THEN RAISE EXCEPTION 'Existing proofs changed';END IF;
 IF(SELECT count(*)FROM public.lts_expense_effective_read_cache WHERE user_id='00000000-0000-4000-8000-000000000002')<>5 THEN RAISE EXCEPTION 'Other owner changed';END IF;
 BEGIN EXECUTE(SELECT sql FROM v348_income_sql);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V348_INCOME_EXISTING_EVIDENCE'THEN RAISE EXCEPTION 'Income replay accepted';END IF;
 EXECUTE 'SET LOCAL ROLE authenticated';
 BEGIN PERFORM 1 FROM public.lts_workbook_nonspend_source_v343;RAISE EXCEPTION 'Private view exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
END$test$;
SELECT jsonb_build_object('pass',true,'version',348,'part','income','rejection_cases',(SELECT count(*)FROM v348_income_cases),'receipt_adjustment_not_spending',true,'raw_source_preserved',true,'existing_receipt_rules_preserved',true,'private_access_denied',true,'owner_isolation',true,'replay_rejected',true);
ROLLBACK;
''')
