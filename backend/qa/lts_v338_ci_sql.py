"""Native negative-workbook transfer identity contract; synthetic data only."""
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
base=subprocess.check_output([sys.executable,str(ROOT/'backend/qa/lts_v336_ci_sql.py')],text=True)
assert base.count('\nROLLBACK;')==1
print(base.rsplit('\nROLLBACK;',1)[0])
print(r"""
INSERT INTO public.evento_base VALUES
 ('00000000-0000-4000-8000-000000000001',3,'{"dia":"2020-02-02","desc":"Recebimento Itaú para C6","conta":"C6","efeito":"entrada","valor":25}'),
 ('00000000-0000-4000-8000-000000000001',4,'{"dia":"2020-02-12","desc":"Transferência Itaú para C6","conta":"Itau","efeito":"saida","valor":25}');
INSERT INTO public.v336_history VALUES
 ('2020-02-02','C6','Recebimento Itaú para C6',-25,'legacy_fix86','evento_base:3','source','assigned',3,'2020-02-02',false,false,'Unknown','Unknown','None',false),
 ('2020-02-12','Itaú','Transferência Itaú para C6',25,'legacy_fix86','evento_base:4','source','assigned',4,'2020-02-12',false,false,'Unknown','Unknown','None',true);
CREATE TEMP TABLE v338_before AS SELECT * FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31');
CREATE TEMP TABLE v338_sources AS SELECT jsonb_build_object(
 'raw',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM public.evento_base t),
 'history',(SELECT jsonb_agg(to_jsonb(t) ORDER BY source_ref) FROM public.v336_history t)) j;
CREATE TEMP TABLE v338_epoch AS SELECT epoch FROM public.lts_read_cache_epoch_v242;
INSERT INTO public.lts_v229_read_cache VALUES('00000000-0000-4000-8000-000000000001');
""")
patch=(ROOT/'backend/patches/v338/workbook_transfer_reversals.sql').read_text()
print(patch)
print(r"""
INSERT INTO public.lts_workbook_transfer_reversal_v338
 (user_id,legacy_index,source_payload,workbook_sha256,workbook_sheet,workbook_row,workbook_through,
 document_date,document_description,document_amount,document_category,origin_bank,destination_bank,leg_direction,
 flow_sheet,flow_date_cell,flow_value_cell,flow_date,flow_value,flow_opening,flow_entries,flow_exits,flow_closing,flow_other_component)
 SELECT usuario_id,idx,dados,repeat('a',64),'Ledger',100+idx,'2020-12-31',
 (dados->>'dia')::date,dados->>'desc',-25,'Transferência Bancária','Itaú','C6',dados->>'efeito',
 'Fluxo de Caixa','AA3',CASE idx WHEN 3 THEN 'AA204' ELSE 'AA72' END,(dados->>'dia')::date,-25,
 100,CASE idx WHEN 3 THEN 25 ELSE 50 END,CASE idx WHEN 3 THEN 50 ELSE 25 END,
 75+CASE idx WHEN 3 THEN 0 ELSE 50 END,50
 FROM public.evento_base WHERE idx IN(3,4);
DO $test$
BEGIN
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242)<>(SELECT epoch+1 FROM v338_epoch)
 OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache)
 THEN RAISE EXCEPTION 'Reversal evidence did not invalidate derived readers';END IF;
 IF (SELECT count(*) FROM public.lts_workbook_transfer_identity_v338('00000000-0000-4000-8000-000000000001'))<>4
 THEN RAISE EXCEPTION 'Positive and negative evidence did not both resolve';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')
 WHERE source='legacy_fix86' AND (NOT internal_transfer OR NOT excluded_from_spend OR category<>'Transferência própria'))
 THEN RAISE EXCEPTION 'Reversal transfer identity missing';END IF;
 IF (SELECT jsonb_agg(to_jsonb(t)-ARRAY['internal_transfer','category','counterparty','excluded_from_spend'] ORDER BY source_ref) FROM v338_before t)
 IS DISTINCT FROM (SELECT jsonb_agg(to_jsonb(t)-ARRAY['internal_transfer','category','counterparty','excluded_from_spend'] ORDER BY source_ref)
 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')t)
 THEN RAISE EXCEPTION 'Cash, date, bank, source or unrelated attribute changed';END IF;
 IF (SELECT to_jsonb(t) FROM v338_before t WHERE source='other') IS DISTINCT FROM
 (SELECT to_jsonb(t) FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')t WHERE source='other')
 THEN RAISE EXCEPTION 'Unrelated record changed';END IF;
END $test$;
CREATE TEMP TABLE v338_cases AS SELECT name,replace(replace(replace(mutation,'idx=2','idx=4'),'evento_base:2','evento_base:4'),$old$'2'$old$,$new$'4'$new$) mutation
 FROM v336_cases WHERE name NOT LIKE 'document %' AND name<>'other evidence owner';
INSERT INTO v338_cases VALUES
 ('other evidence owner',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET user_id='00000000-0000-4000-8000-000000000099' WHERE legacy_index=4$q$),
 ('document date',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET document_date='2020-02-13' WHERE legacy_index=4$q$),
 ('document value',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET document_amount=-26 WHERE legacy_index=4$q$),
 ('document text',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET document_description='Other' WHERE legacy_index=4$q$),
 ('flow value',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET flow_value=-26 WHERE legacy_index=4$q$),
 ('flow date column',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET flow_value_cell='AB72' WHERE legacy_index=4$q$),
 ('flow balance',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET flow_closing=0 WHERE legacy_index=4$q$),
 ('flow component total',$q$UPDATE public.lts_workbook_transfer_reversal_v338 SET flow_other_component=51 WHERE legacy_index=4$q$),
 ('raw bank',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{conta}','"Bradesco"') WHERE idx=4$q$);
DO $test$
DECLARE r record;
BEGIN
 FOR r IN SELECT * FROM v338_cases LOOP
  BEGIN
   EXECUTE r.mutation;
   IF EXISTS(SELECT 1 FROM public.lts_historical_effective_cash_v3('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31') WHERE source_ref='evento_base:4' AND internal_transfer)
   THEN RAISE EXCEPTION 'Unproved reversal accepted: %',r.name;END IF;
   RAISE EXCEPTION USING ERRCODE='V3380',MESSAGE='rollback fixture mutation';
  EXCEPTION WHEN SQLSTATE 'V3380' OR check_violation THEN NULL;END;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.lts_workbook_transfer_identity_v338(NULL)) OR EXISTS(SELECT 1 FROM public.lts_workbook_transfer_identity_v338('00000000-0000-4000-8000-000000000099'))
 THEN RAISE EXCEPTION 'Owner scope leaked';END IF;
 EXECUTE 'SET LOCAL ROLE authenticated';
 BEGIN PERFORM 1 FROM public.lts_workbook_transfer_reversal_v338;RAISE EXCEPTION 'Internal table readable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM * FROM public.lts_workbook_transfer_identity_v338('00000000-0000-4000-8000-000000000001');RAISE EXCEPTION 'Internal identity callable';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE 'RESET ROLE';
END $test$;
CREATE TEMP TABLE v338_replay AS SELECT pg_get_functiondef('public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure) definition;
""")
print(patch)
print(r"""
DO $test$
BEGIN
 IF (SELECT definition FROM v338_replay) IS DISTINCT FROM pg_get_functiondef('public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay changed history';END IF;
 IF (SELECT j FROM v336_attributes) IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Function attributes changed';END IF;
 IF (SELECT j FROM v338_sources) IS DISTINCT FROM (SELECT jsonb_build_object(
 'raw',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM public.evento_base t),
 'history',(SELECT jsonb_agg(to_jsonb(t) ORDER BY source_ref) FROM public.v336_history t)))
 THEN RAISE EXCEPTION 'Sources changed';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'version',338,'rejection_cases',(SELECT count(*) FROM v338_cases),
 'both_signed_reversals',true,'positive_proofs_preserved',true,'cash_identity_exact',true,'unrelated_rows_exact',true,
 'function_attributes_exact',true,'source_records_unchanged',true,'owner_scope',true,'internal_access_denied',true,
 'cache_invalidation',true,'replay_noop',true,'dependency_fixture_not_production_certificate',true) receipt;
ROLLBACK;
""")
