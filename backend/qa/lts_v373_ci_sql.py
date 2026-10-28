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
DO $$BEGIN
 IF public.lts_browser_expense_composition_v346('2022-04-01','2022-04-30','parent')IS DISTINCT FROM(SELECT j FROM v373_old)THEN RAISE EXCEPTION 'Published reader changed';END IF;
 IF EXISTS(SELECT 1 FROM v373_attrs a JOIN pg_proc p ON p.proname=a.proname AND p.pronamespace='public'::regnamespace WHERE a.j IS DISTINCT FROM to_jsonb(p)-'prosrc')THEN RAISE EXCEPTION 'Existing function attributes changed';END IF;
END$$;
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
 IF(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.v346_financial x)IS DISTINCT FROM(SELECT j FROM v373_financial)THEN RAISE EXCEPTION 'Financial rows changed';END IF;
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
