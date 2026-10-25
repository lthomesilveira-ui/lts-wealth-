"""Native PostgreSQL tests for exact workbook transfer evidence and history reader."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
print(r"""
BEGIN;
CREATE TABLE public.evento_base(usuario_id uuid,idx integer,dados jsonb,PRIMARY KEY(usuario_id,idx));
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,
 beneficiary text,property_code text,category_label text,decision_basis text);
CREATE TABLE public.lts_expense_realized(user_id uuid,source_table text,source_ref text,
 category_candidate text,category_raw text,counterparty_candidate text,center_cost_candidate text,exclude_from_spend boolean);
CREATE TABLE public.v336_history(event_date date,account text,description text,signed_amount numeric,
 source text,source_ref text,confidence text,account_assignment text,legacy_index integer,
 original_date date,displaced boolean,internal_transfer boolean,category text,counterparty text,
 center_cost text,excluded_from_spend boolean);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,0);
CREATE TABLE public.lts_v229_read_cache(user_id uuid);
INSERT INTO public.lts_v229_read_cache VALUES('00000000-0000-4000-8000-000000000001');
CREATE FUNCTION public.lts_historical_effective_cash_v2(uuid,date,date)
 RETURNS SETOF public.v336_history LANGUAGE sql AS $$SELECT * FROM public.v336_history WHERE event_date BETWEEN $2 AND $3$$;
INSERT INTO public.evento_base VALUES
 ('00000000-0000-4000-8000-000000000001',1,'{"dia":"2020-01-02","desc":"Transferência Itaú para Bradesco","conta":"Itaú","efeito":"saida","valor":25}'),
 ('00000000-0000-4000-8000-000000000001',2,'{"dia":"2020-01-02","desc":"Recebimento Itaú para Bradesco","conta":"Bradesco","efeito":"entrada","valor":25}');
INSERT INTO public.v336_history VALUES
 ('2020-01-02','Itaú','Transferência Itaú para Bradesco',-25,'legacy_fix86','evento_base:1','source','assigned',1,'2020-01-02',false,false,'A classificar','Não identificado','Não atribuído',true),
 ('2020-01-02','Bradesco','Recebimento Itaú para Bradesco',25,'legacy_fix86','evento_base:2','source','assigned',2,'2020-01-02',false,false,'A classificar','Não identificado','Não atribuído',false),
 ('2020-01-03','Itaú','Food',-9,'other','expense:3','source','assigned',NULL,'2020-01-03',false,false,'Food','Merchant','Não atribuído',false);
"""
)
print((ROOT/'backend/qa/fixtures/v336_invalidate.sql').read_text())
print((ROOT/'backend/qa/fixtures/v336_history_v3.sql').read_text())
print(r"""
CREATE TEMP TABLE v336_before AS SELECT * FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31');
CREATE TEMP TABLE v336_attributes AS SELECT to_jsonb(p)-'prosrc' j FROM pg_proc p WHERE oid='public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure;
CREATE TEMP TABLE v336_sources AS SELECT jsonb_build_object(
 'raw',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM public.evento_base t),
 'history',(SELECT jsonb_agg(to_jsonb(t) ORDER BY source_ref) FROM public.v336_history t),
 'decisions',(SELECT jsonb_agg(to_jsonb(t)) FROM public.lts_v178_review_decision t)) j;
"""
)
patch = (ROOT/'backend/patches/v336/workbook_transfer_identity.sql').read_text()
print(patch)
print(r"""
INSERT INTO public.lts_workbook_transfer_evidence_v336
 (user_id,legacy_index,source_payload,workbook_sha256,workbook_sheet,workbook_row,workbook_through,
 document_date,document_description,document_amount,document_category,origin_bank,destination_bank,leg_direction)
 SELECT e.usuario_id,e.idx,e.dados,repeat('a',64),'Ledger',100+e.idx,'2020-01-31',
 (e.dados->>'dia')::date,e.dados->>'desc',25,'Transferência Bancária','Itaú','Bradesco',e.dados->>'efeito'
 FROM public.evento_base e;
DO $test$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.lts_workbook_transfer_identity_v336('00000000-0000-4000-8000-000000000001');
 IF n<>2 THEN RAISE EXCEPTION 'Both documented legs must resolve';END IF;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242)<>1 OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache)
 THEN RAISE EXCEPTION 'Evidence change did not invalidate derived readers';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31') WHERE source='legacy_fix86' AND
  (NOT internal_transfer OR NOT excluded_from_spend OR category<>'Transferência própria' OR counterparty<>'Própria'))
 THEN RAISE EXCEPTION 'Documented transfer classification not applied';END IF;
 IF (SELECT sum(signed_amount) FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31') WHERE source='legacy_fix86')<>0
 THEN RAISE EXCEPTION 'Consolidated pair is not neutral';END IF;
 IF (SELECT jsonb_agg(to_jsonb(t)-ARRAY['internal_transfer','category','counterparty','excluded_from_spend'] ORDER BY source_ref) FROM v336_before t)
 IS DISTINCT FROM (SELECT jsonb_agg(to_jsonb(t)-ARRAY['internal_transfer','category','counterparty','excluded_from_spend'] ORDER BY source_ref)
 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')t)
 THEN RAISE EXCEPTION 'Amount, date, bank, source or other history attributes changed';END IF;
 IF (SELECT to_jsonb(t) FROM v336_before t WHERE source='other') IS DISTINCT FROM
 (SELECT to_jsonb(t) FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')t WHERE source='other')
 THEN RAISE EXCEPTION 'Unrelated classification changed';END IF;
END $test$;

CREATE TEMP TABLE v336_cases(name text,mutation text);
INSERT INTO v336_cases VALUES
 ('raw amount',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{valor}','26') WHERE idx=2$q$),
 ('raw date',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{dia}','"2020-01-04"') WHERE idx=2$q$),
 ('raw text',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{desc}','"Other"') WHERE idx=2$q$),
 ('raw direction',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{efeito}','"saida"') WHERE idx=2$q$),
 ('raw metadata drift',$q$UPDATE public.evento_base SET dados=dados||'{"edited":true}' WHERE idx=2$q$),
 ('other raw owner',$q$UPDATE public.evento_base SET usuario_id='00000000-0000-4000-8000-000000000099' WHERE idx=2$q$),
 ('other evidence owner',$q$UPDATE public.lts_workbook_transfer_evidence_v336 SET user_id='00000000-0000-4000-8000-000000000099' WHERE legacy_index=2$q$),
 ('document amount',$q$UPDATE public.lts_workbook_transfer_evidence_v336 SET document_amount=26 WHERE legacy_index=2$q$),
 ('document date',$q$UPDATE public.lts_workbook_transfer_evidence_v336 SET document_date='2020-01-04' WHERE legacy_index=2$q$),
 ('document description',$q$UPDATE public.lts_workbook_transfer_evidence_v336 SET document_description='Other' WHERE legacy_index=2$q$),
 ('effective bank',$q$UPDATE public.v336_history SET account='C6' WHERE source_ref='evento_base:2'$q$),
 ('effective amount',$q$UPDATE public.v336_history SET signed_amount=26 WHERE source_ref='evento_base:2'$q$),
 ('effective original date',$q$UPDATE public.v336_history SET original_date='2020-01-04' WHERE source_ref='evento_base:2'$q$),
 ('effective description',$q$UPDATE public.v336_history SET description='Other' WHERE source_ref='evento_base:2'$q$),
 ('later purpose',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','2',NULL,NULL,'Saúde','user_confirmed')$q$),
 ('later beneficiary',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','2','Larissa',NULL,NULL,'user_confirmed')$q$),
 ('later property',$q$INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','2',NULL,'other_property',NULL,'user_confirmed')$q$);
DO $test$
DECLARE r record;
BEGIN
 FOR r IN SELECT * FROM v336_cases LOOP
  BEGIN
   EXECUTE r.mutation;
   IF EXISTS(SELECT 1 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')
    WHERE source_ref='evento_base:2' AND internal_transfer)
   THEN RAISE EXCEPTION 'Unproven identity accepted: %',r.name;END IF;
   RAISE EXCEPTION USING ERRCODE='V3360',MESSAGE='rollback fixture mutation';
  EXCEPTION WHEN SQLSTATE 'V3360' THEN NULL;
  END;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.lts_workbook_transfer_identity_v336(NULL)) OR
 EXISTS(SELECT 1 FROM public.lts_workbook_transfer_identity_v336('00000000-0000-4000-8000-000000000099'))
 THEN RAISE EXCEPTION 'Owner scope leaked';END IF;
 INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','2',NULL,NULL,'Transferência própria','user_confirmed');
 IF (SELECT count(*) FROM public.lts_workbook_transfer_identity_v336('00000000-0000-4000-8000-000000000001'))<>2
 THEN RAISE EXCEPTION 'Compatible explicit owner confirmation was lost';END IF;
 DELETE FROM public.lts_v178_review_decision;
END $test$;
DO $test$
BEGIN
 EXECUTE 'SET LOCAL ROLE authenticated';
 BEGIN
  PERFORM 1 FROM public.lts_workbook_transfer_evidence_v336;
  RAISE EXCEPTION 'Authenticated role could read internal evidence';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM * FROM public.lts_workbook_transfer_identity_v336('00000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Authenticated role could invoke internal identity';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 EXECUTE 'RESET ROLE';
END $test$;
CREATE TEMP TABLE v336_replay AS SELECT pg_get_functiondef('public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure) definition;
"""
)
print(patch)
print(r"""
DO $test$
BEGIN
 IF (SELECT definition FROM v336_replay) IS DISTINCT FROM pg_get_functiondef('public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay was not a no-op';END IF;
 IF (SELECT j FROM v336_attributes) IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'History function attributes changed';END IF;
 IF (SELECT j FROM v336_sources) IS DISTINCT FROM (SELECT jsonb_build_object(
 'raw',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM public.evento_base t),
 'history',(SELECT jsonb_agg(to_jsonb(t) ORDER BY source_ref) FROM public.v336_history t),
 'decisions',(SELECT jsonb_agg(to_jsonb(t)) FROM public.lts_v178_review_decision t)))
 THEN RAISE EXCEPTION 'Source records changed';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'rejection_cases',(SELECT count(*) FROM v336_cases),
 'both_legs_preserved',true,'consolidated_pair_neutral',true,'unrelated_rows_exact',true,
 'function_attributes_exact',true,'source_records_unchanged',true,'owner_scope',true,
 'authenticated_internal_access_denied',true,'cache_invalidation',true,'replay_noop',true,
 'dependency_fixture_not_production_certificate',true) receipt;
ROLLBACK;
"""
)
