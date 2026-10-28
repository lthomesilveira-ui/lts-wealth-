"""PDF detail is read-only, source-bound and isolated from published readers."""
from pathlib import Path
import subprocess
import sys

R=Path(__file__).resolve().parents[2]
base=subprocess.run([sys.executable,str(R/'backend/qa/lts_v346_ci_sql.py')],check=True,capture_output=True,text=True).stdout
assert base.rstrip().endswith('ROLLBACK;')
print(base[:base.rindex('ROLLBACK;')])
print(r'''
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
ALTER TABLE public.v346_financial ADD COLUMN description text DEFAULT 'Synthetic card';
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE v373_old AS SELECT public.lts_browser_expense_composition_v346('2022-04-01','2022-04-30','parent')j;
CREATE TEMP TABLE v373_attrs AS SELECT proname,to_jsonb(p)-'prosrc' j FROM pg_proc p WHERE pronamespace='public'::regnamespace;
CREATE TEMP TABLE v373_financial AS SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)j FROM public.v346_financial x;
''')
print((R/'backend/patches/v373/pdf_history_composition.sql').read_text())
print(r'''
INSERT INTO lts_history_private_v373.pdf_parent(user_id,parent_key,signature,source_sha256,source_file,library_file_id,issuer,family,document_date,due_date,reported_total,source_rows,validation)
SELECT user_id,row_key,public.lts_card_history_signature_v346(to_jsonb(r)),repeat('b',64),'Fatura sintética.pdf','synthetic-file','Banco fictício','synthetic','2022-03-20','2022-04-01',75,3,'{"subtotals_match":true}'
FROM public.v346_financial r WHERE user_id='00000000-0000-4000-8000-000000000001';
INSERT INTO lts_history_private_v373.pdf_item(user_id,parent_key,ordinal,source_page,source_column,extracted_line,original_description,description,bank_category,amount,purchase_day_month,last4,installment_number,installments)VALUES
('00000000-0000-4000-8000-000000000001','parent',1,2,1,10,'Compra sintética 02/03','Compra sintética','Categoria do emissor',80,'18/02','0000',2,3),
('00000000-0000-4000-8000-000000000001','parent',2,2,1,12,'Crédito sintético','Crédito sintético',NULL,-5,'19/02','0000',NULL,NULL),
('00000000-0000-4000-8000-000000000001','parent',3,2,2,15,'Registro zero','Registro zero',NULL,0,'20/02',NULL,NULL,NULL);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE j jsonb;p jsonb;
BEGIN
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'partial'OR(j->>'total')::numeric<>100 OR(j->>'identified_total')::numeric<>75
 OR(j->>'residual_total')::numeric<>25 OR(j->>'count')::int<>3 OR(j->>'nonzero_count')::int<>2
 THEN RAISE EXCEPTION 'Signed documentary detail or residual changed';END IF;
 p:=j#>'{rows,0}';
 IF p->>'date'IS NOT NULL OR p->>'date_kind'<>'purchase_day_month'OR p->>'date_label'<>'18/02'
 OR p#>>'{source,kind}'<>'bank_invoice_pdf'OR p#>>'{source,date_cell}'IS NOT NULL
 OR p#>>'{document,installment_number}'<>'2'THEN RAISE EXCEPTION 'Unknown year or false spreadsheet cells';END IF;
 IF has_table_privilege('authenticated','lts_history_private_v373.pdf_item','SELECT')
 OR has_table_privilege('authenticated','lts_history_private_v373.pdf_parent','INSERT')THEN RAISE EXCEPTION 'Private tables exposed';END IF;
END $test$;
RESET ROLE;
DO $bridge$
DECLARE j jsonb;
BEGIN
 UPDATE public.v346_financial SET coverage_mode='card_invoice_aggregate_fallback'
 WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key='parent';
 INSERT INTO public.v346_financial(user_id,row_key,event_date,transaction_date,competence_month,amount,category,account_source,source_table,source_ref,coverage_mode,management_group,management_subgroup,description)
 SELECT user_id,'original-adjustment',event_date,transaction_date,competence_month,-25,'Original adjustment',account_source,source_table,'2','card_workbook_signed_adjustment_v235','Original adjustment','Original adjustment',description
 FROM public.v346_financial WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key='parent';
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'complete'OR(j->>'unexplained_total')::numeric<>0
 OR(j->>'residual_total')::numeric<>25 OR(j#>>'{reconciliation,adjustments_total}')::numeric<>-25
 OR(j#>>'{reconciliation,net_total}')::numeric<>75 THEN RAISE EXCEPTION 'Original signed adjustment not reconciled';END IF;
 UPDATE public.v346_financial SET coverage_mode='unrelated_refund'WHERE row_key='original-adjustment';
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'partial'OR j->>'reconciliation'IS NOT NULL THEN RAISE EXCEPTION 'Unrelated refund used as balancing item';END IF;
 UPDATE public.v346_financial SET coverage_mode='card_workbook_signed_adjustment_v235'WHERE row_key='original-adjustment';
 INSERT INTO public.v346_financial(user_id,row_key,event_date,transaction_date,competence_month,amount,category,account_source,source_table,source_ref,coverage_mode,management_group,management_subgroup,description)
 SELECT user_id,'another-positive',event_date,transaction_date,competence_month,10,category,account_source,source_table,'3',coverage_mode,management_group,management_subgroup,description
 FROM public.v346_financial WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key='parent';
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'partial'OR j->>'reconciliation'IS NOT NULL THEN RAISE EXCEPTION 'Ambiguous consolidated rows auto-linked';END IF;
 DELETE FROM public.v346_financial WHERE row_key IN('original-adjustment','another-positive');
 UPDATE public.v346_financial SET coverage_mode='card_category_allocated_history'
 WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key='parent';
END $bridge$;
DO $$BEGIN
 IF public.lts_browser_expense_composition_v346('2022-04-01','2022-04-30','parent')IS DISTINCT FROM(SELECT j FROM v373_old)THEN RAISE EXCEPTION 'Published reader changed';END IF;
 IF EXISTS(SELECT 1 FROM v373_attrs a JOIN pg_proc p ON p.proname=a.proname AND p.pronamespace='public'::regnamespace WHERE a.j IS DISTINCT FROM to_jsonb(p)-'prosrc')THEN RAISE EXCEPTION 'Existing function attributes changed';END IF;
END$$;
DO $test$
DECLARE j jsonb;
BEGIN
 UPDATE lts_history_private_v373.pdf_item SET purchase_date='2022-02-18'WHERE ordinal=1;
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j#>>'{rows,0,date_kind}'<>'purchase'OR j#>>'{rows,0,date}'<>'2022-02-18'THEN RAISE EXCEPTION 'Documented full date lost';END IF;
 UPDATE lts_history_private_v373.pdf_item SET purchase_date=NULL WHERE ordinal=1;
 BEGIN
  UPDATE lts_history_private_v373.pdf_item SET purchase_date='2022-01-01'WHERE ordinal=1;
  RAISE EXCEPTION 'Contradictory date accepted';
 EXCEPTION WHEN check_violation THEN NULL;END;
 INSERT INTO public.lts_card_history_parent_v346 SELECT user_id,row_key,public.lts_card_history_signature_v346(to_jsonb(r)),'{}',now()
 FROM public.v346_financial r WHERE user_id='00000000-0000-4000-8000-000000000001';
 INSERT INTO public.lts_card_history_item_v346 VALUES('00000000-0000-4000-8000-000000000001','parent',repeat('c',64),'Original.xlsx','Original',1,'2022-04-01','2022-04-01',100,100,'Original item','Original category','Synthetic card',NULL,NULL,NULL);
 IF public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent')IS DISTINCT FROM public.lts_browser_expense_composition_v346('2022-04-01','2022-04-30','parent')THEN RAISE EXCEPTION 'Existing workbook composition was replaced or duplicated';END IF;
 DELETE FROM public.lts_card_history_item_v346 WHERE source_hash=repeat('c',64);
 DELETE FROM public.lts_card_history_parent_v346;
END $test$;
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$DECLARE j jsonb;BEGIN
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'missing'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Other owner can see sources';END IF;
END$$;
RESET ROLE;
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000001',true);
DO $test$
DECLARE j jsonb;
BEGIN
 UPDATE lts_history_private_v373.pdf_parent SET signature=signature||'{"amount":101}';
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'stale'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Changed parent still bound';END IF;
 UPDATE lts_history_private_v373.pdf_parent SET signature=signature||'{"amount":100}';
 DELETE FROM lts_history_private_v373.pdf_item WHERE ordinal=2;
 j:=public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');
 IF j->>'status'<>'stale'OR j->>'document_status'<>'incomplete_source'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Incomplete source presented as checked';END IF;
 IF(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.v346_financial x)IS DISTINCT FROM(SELECT saved.j FROM v373_financial saved)THEN RAISE EXCEPTION 'Financial rows changed';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE proname='lts_browser_expense_composition_v373'AND prosecdef)
 OR has_function_privilege('anon','public.lts_browser_expense_composition_v373(date,date,text)','EXECUTE')THEN RAISE EXCEPTION 'Public elevation or anonymous access';END IF;
END $test$;
SELECT set_config('app.synthetic_uid','',true);
DO $$BEGIN
 BEGIN PERFORM public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent');RAISE EXCEPTION 'Missing identity accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END$$;
SELECT jsonb_build_object('version',373,'pass',true,'old_reader_and_attributes_unchanged',true,'owner_isolation',true,'unknown_purchase_year_preserved',true,'signed_sources',true,'parent_signature_guard',true,'complete_document_guard',true,'financial_rows_unchanged',true,'private_tables_unexposed',true,'public_wrapper_invoker',true);
ROLLBACK;
''')
