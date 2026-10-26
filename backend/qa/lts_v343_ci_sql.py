"""Workbook nonspending contract in native PostgreSQL; synthetic data only."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
print(r"""
BEGIN;
CREATE TABLE public.historico_analitico(usuario_id uuid,idx integer,dados jsonb,PRIMARY KEY(usuario_id,idx));
CREATE TABLE public.lts_reconciliation_evidence(id uuid PRIMARY KEY,user_id uuid,evidence_date date,account text,amount numeric,description text,evidence_type text,source_ref text,status text,metadata jsonb);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text);
CREATE TABLE public.lts_expense_analytics_candidate(user_id uuid,source_table text,source_ref text,event_date date,description_raw text,account_raw text,category_raw text,macro_raw text,direction text,amount numeric,is_future_vs_checkpoint boolean,raw_payload jsonb,semantic_rule_id text,semantic_nature text,category_candidate text,counterparty_candidate text,center_cost_candidate text,is_internal_transfer boolean,is_asset_movement boolean,exclude_from_spend boolean,semantic_confidence text);
CREATE TABLE public.lts_projection_replacement_rule(id text,user_id uuid,source_table text,description_exact text,account_exact text,date_from date,date_to date,action text,replacement_source text,replacement_ref text,reason text,evidence jsonb,active boolean,created_at timestamptz,updated_at timestamptz);
ALTER TABLE public.historico_analitico ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_reconciliation_evidence ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.historico_analitico,public.lts_reconciliation_evidence,public.lts_v178_review_decision,public.lts_expense_analytics_candidate,public.lts_projection_replacement_rule TO service_role;
INSERT INTO public.historico_analitico
SELECT '00000000-0000-4000-8000-000000000001',n,
 jsonb_build_object('c',CASE WHEN n=1 THEN 'Família' WHEN n IN(2,3,4) THEN 'Impostos' ELSE 'Salário' END,
 'd',CASE WHEN n=4 THEN '2015-03-01' ELSE make_date(2015,n,1)::text END,
 'e','saida','m','','v',CASE WHEN n IN(3,4) THEN 30 ELSE n*10 END,
 'x',CASE WHEN n=1 THEN 'Família' WHEN n=2 THEN 'Nota Fiscal Paulista' WHEN n IN(3,4) THEN 'FGTS' ELSE 'Salário' END,'h','synthetic_'||n)
FROM generate_series(1,5)n;
INSERT INTO public.historico_analitico SELECT '00000000-0000-4000-8000-000000000002',idx,dados FROM public.historico_analitico;
INSERT INTO public.lts_expense_analytics_candidate
SELECT usuario_id,'historico_analitico',idx::text,(dados->>'d')::date,dados->>'x','Itaú',dados->>'c','',dados->>'e',(dados->>'v')::numeric,false,dados,NULL,NULL,dados->>'c',NULL,NULL,false,false,false,'source' FROM public.historico_analitico;
""")
print((ROOT/'backend/qa/fixtures/v343_expense_before.sql').read_text())
print(r"""
CREATE TEMP TABLE v343_before AS SELECT * FROM public.lts_expense_realized;
CREATE TEMP TABLE v343_sources AS SELECT jsonb_agg(to_jsonb(h)ORDER BY usuario_id,idx) j FROM public.historico_analitico h;
CREATE TEMP TABLE v343_attributes AS SELECT oid,relowner,relacl,reloptions FROM pg_class WHERE oid='public.lts_expense_realized'::regclass;
""")
patch=(ROOT/'backend/patches/v343/workbook_nonspend.sql').read_text()
print(patch)
print(r"""
INSERT INTO public.lts_reconciliation_evidence
SELECT ('10000000-0000-4000-8000-'||lpad(idx::text,12,'0'))::uuid,usuario_id,(dados->>'d')::date,'Itaú',(dados->>'v')::numeric,dados->>'x',
 'historical_workbook_nonspend_v343','historico_analitico:'||idx,'documented',
 jsonb_build_object('schema','workbook-nonspend-v343','source_table','historico_analitico','source_ref',idx::text,'source_payload',dados,
 'nature',CASE WHEN idx IN(3,4)THEN 'asset_withdrawal' ELSE 'receipt' END,
 'documented_direction','entrada','workbook_sheet','Pagamentos e Recebimentos','workbook_rows',CASE WHEN idx IN(3,4)THEN '[103,104]'::jsonb ELSE jsonb_build_array(100+idx)END,
 'tuple_multiplicity',CASE WHEN idx IN(3,4)THEN 2 ELSE 1 END,'flow_sheet','Fluxo de Caixa','flow_label_cell',CASE idx WHEN 1 THEN 'A44' WHEN 2 THEN 'A50' ELSE 'A30' END,'income_sum_row',7,'workbook_sha256',repeat('a',64))
FROM public.historico_analitico WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND idx<=4;
DO $test$
BEGIN
 IF (SELECT count(*)FROM public.lts_workbook_nonspend_source_v343)<>4 THEN RAISE EXCEPTION 'Missing documentary sources';END IF;
 IF (SELECT count(*)FROM public.lts_expense_realized WHERE exclude_from_spend)<>4 THEN RAISE EXCEPTION 'Receipts still counted as spending';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_expense_realized WHERE user_id='00000000-0000-4000-8000-000000000002' AND exclude_from_spend)
 OR EXISTS(SELECT 1 FROM public.lts_expense_realized WHERE source_ref='5' AND exclude_from_spend) THEN RAISE EXCEPTION 'Unrelated source excluded';END IF;
 IF (SELECT jsonb_agg(to_jsonb(h)ORDER BY usuario_id,idx)FROM public.historico_analitico h) IS DISTINCT FROM (SELECT j FROM v343_sources)
 THEN RAISE EXCEPTION 'Raw source changed';END IF;
 IF EXISTS((SELECT to_jsonb(b)-'exclude_from_spend' j FROM v343_before b EXCEPT ALL SELECT to_jsonb(a)-'exclude_from_spend' FROM public.lts_expense_realized a)
 UNION ALL (SELECT to_jsonb(a)-'exclude_from_spend' FROM public.lts_expense_realized a EXCEPT ALL SELECT to_jsonb(b)-'exclude_from_spend' FROM v343_before b))
 THEN RAISE EXCEPTION 'Amount, sign, date, cash or classification changed';END IF;
 IF (SELECT row(oid,relowner,relacl,reloptions)FROM pg_class WHERE oid='public.lts_expense_realized'::regclass)
 IS DISTINCT FROM (SELECT row(oid,relowner,relacl,reloptions)FROM v343_attributes) THEN RAISE EXCEPTION 'View attributes changed';END IF;
END $test$;
CREATE TEMP TABLE v343_cases(name text,mutation text);
INSERT INTO v343_cases VALUES
 ('raw amount',$q$UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{v}','11') WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND idx=1$q$),
 ('raw hash',$q$UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{h}','"changed"') WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND idx=1$q$),
 ('raw direction',$q$UPDATE public.historico_analitico SET dados=jsonb_set(dados,'{e}','"entrada"') WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND idx=1$q$),
 ('later decision',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','historico_analitico','1','Explicit later decision')$q$),
 ('conflicting proof',$q$INSERT INTO public.lts_reconciliation_evidence SELECT '20000000-0000-4000-8000-000000000001',user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata FROM public.lts_reconciliation_evidence WHERE source_ref='historico_analitico:1'$q$);
INSERT INTO v343_cases SELECT key,'UPDATE public.lts_reconciliation_evidence SET metadata=jsonb_set(metadata,'||quote_literal('{'||key||'}')||','||quote_literal(value::text)||'::jsonb) WHERE source_ref=''historico_analitico:1'''
 FROM (VALUES('schema','"invalid"'::jsonb),('source_table','"other"'),('source_ref','"2"'),('source_payload','{}'),('nature','"asset_withdrawal"'),('documented_direction','"saida"'),('workbook_sheet','"other"'),('workbook_rows','null'),('workbook_rows','[0]'),('workbook_rows','[101,101]'),('workbook_rows','["invalid"]'),('tuple_multiplicity','2'),('flow_sheet','"other"'),('flow_label_cell','"A53"'),('income_sum_row','53'),('workbook_sha256','"invalid"')) x(key,value);
INSERT INTO v343_cases SELECT key,'UPDATE public.lts_reconciliation_evidence SET '||key||'='||value||' WHERE source_ref=''historico_analitico:1'''
 FROM (VALUES('status',quote_literal('pending')),('account',quote_literal('Other')),('amount','11'),('evidence_date',quote_literal('2015-01-02')),('description',quote_literal('Other')),('user_id',quote_literal('00000000-0000-4000-8000-000000000003')||'::uuid')) x(key,value);
DO $test$
DECLARE r record;
BEGIN
 FOR r IN SELECT * FROM v343_cases LOOP
  BEGIN
   EXECUTE r.mutation;
   IF EXISTS(SELECT 1 FROM public.lts_workbook_nonspend_source_v343 WHERE source_ref='1') THEN RAISE EXCEPTION 'Invalid proof accepted: %',r.name;END IF;
   IF (SELECT count(*)FROM public.lts_workbook_nonspend_source_v343 WHERE source_ref IN('2','3','4'))<>3 THEN RAISE EXCEPTION 'Unrelated valid proof changed: %',r.name;END IF;
   RAISE EXCEPTION USING ERRCODE='V3430',MESSAGE='rollback fixture mutation';
  EXCEPTION WHEN SQLSTATE 'V3430' THEN NULL;END;
 END LOOP;
 EXECUTE 'SET LOCAL ROLE authenticated';
 BEGIN PERFORM 1 FROM public.lts_workbook_nonspend_source_v343;RAISE EXCEPTION 'Private proof view readable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM 1 FROM public.lts_expense_realized;RAISE EXCEPTION 'Private expense view readable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
END $test$;
CREATE TEMP TABLE v343_replay AS SELECT pg_get_viewdef('public.lts_expense_realized'::regclass,true) definition;
""")
print(patch)
print(r"""
DO $test$
BEGIN
 IF (SELECT definition FROM v343_replay)IS DISTINCT FROM pg_get_viewdef('public.lts_expense_realized'::regclass,true) THEN RAISE EXCEPTION 'Replay changed the expense reader';END IF;
 IF (SELECT count(*)FROM public.lts_workbook_nonspend_source_v343)<>4 THEN RAISE EXCEPTION 'Replay lost proof';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'version',343,'rejection_cases',(SELECT count(*)FROM v343_cases),'source_preserved',true,'cash_and_categories_preserved',true,'view_attributes_preserved',true,'equal_tuples_preserved',true,'later_decisions_respected',true,'owner_isolation',true,'private_access_denied',true,'replay_noop',true) receipt;
ROLLBACK;
""")
