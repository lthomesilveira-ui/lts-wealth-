"""Synthetic documentary cycles: several ledger rows and several PDF sources."""
from pathlib import Path
import subprocess,sys
R=Path(__file__).resolve().parents[2]
base=subprocess.run([sys.executable,str(R/'backend/qa/lts_v373_ci_sql.py')],check=True,capture_output=True,text=True).stdout
assert base.rstrip().endswith('ROLLBACK;')
print(base[:base.rindex('ROLLBACK;')])
print(r'''
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000001',true);
CREATE FUNCTION public.lts_browser_expense_detail_v353(p_from date,p_to date,p_scope jsonb DEFAULT '{}',p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT public.lts_browser_expense_detail_v346(p_from,p_to,NULL,NULL,p_offset,p_limit,p_query)||jsonb_build_object('scope',p_scope)$$;
INSERT INTO public.v346_financial(user_id,row_key,event_date,transaction_date,competence_month,amount,category,account_source,source_table,source_ref,coverage_mode,management_group,management_subgroup,description)
SELECT user_id,v.key,event_date,transaction_date,competence_month,v.amount,category,account_source,source_table,v.ref,v.mode,management_group,management_subgroup,description
FROM public.v346_financial CROSS JOIN(VALUES('cycle-parent-a',100,'101','card_invoice_aggregate_fallback'),('cycle-parent-b',25,'102','card_invoice_aggregate_fallback'),('cycle-adjustment',-10,'103','card_workbook_signed_adjustment_v235'))v(key,amount,ref,mode);
CREATE TEMP TABLE v374_before AS SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id,row_key)j FROM public.v346_financial x;
CREATE TEMP TABLE v374_old AS SELECT public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent')j;
CREATE TEMP TABLE v374_old_attrs AS SELECT oid,to_jsonb(p)j FROM pg_proc p WHERE pronamespace='public'::regnamespace;
-- Keep the separate dates recorded for two entries of one invoice cycle.
UPDATE public.v346_financial SET event_date='2022-04-02',transaction_date='2022-04-02'WHERE row_key='cycle-parent-b';
UPDATE v374_before SET j=(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id,row_key)FROM public.v346_financial x);
''')
print((R/'backend/patches/v374/documentary_cycles.sql').read_text())
print(r'''
INSERT INTO lts_history_private_v374.cycle(user_id,cycle_key,booked_on,competence_month,workbook,members,validation)
SELECT '00000000-0000-4000-8000-000000000001','synthetic-cycle','2022-04-01','2022-04-01',
'{"file":"Original fictício.xlsx","sheet":"Pagamentos","parent_rows":[11,12],"adjustment_rows":[13]}',
jsonb_agg(jsonb_build_object('key',row_key,'signature',public.lts_card_history_signature_v346(to_jsonb(r)),'workbook_rows',jsonb_build_array(source_ref::integer))ORDER BY row_key),
'{"accounts":["Synthetic card"],"source_tables":["synthetic_card"],"event_dates":["2022-04-01","2022-04-02"]}'
FROM public.v346_financial r WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key LIKE'cycle-%';
INSERT INTO lts_history_private_v374.binding SELECT user_id,row_key,'synthetic-cycle',public.lts_card_history_signature_v346(to_jsonb(r))FROM public.v346_financial r
WHERE user_id='00000000-0000-4000-8000-000000000001'AND row_key IN('cycle-parent-a','cycle-parent-b');
INSERT INTO lts_history_private_v374.document(user_id,source_sha256,semantic_sha256,cycle_key,source_file,library_file_id,issuer,family,billing_last4,document_date,due_date,reported_total,source_rows,items,validation)VALUES
('00000000-0000-4000-8000-000000000001',repeat('d',64),repeat('e',64),'synthetic-cycle','Fatura A.pdf','synthetic-a','Banco fictício','itau_mastercard','0001','2022-03-20','2022-04-01',75,3,
'[{"source_page":2,"source_column":1,"source_line":1,"description":"Compra A","original_description":"Compra A02/03","amount":80,"purchase_day_month":"18/02","last4":"0001","installment_number":2,"installments":3,"original_category":"Emissor A"},{"source_page":2,"source_column":1,"source_line":3,"description":"Crédito A","original_description":"Crédito A","amount":-5,"purchase_day_month":"18/02","last4":"0001"},{"source_page":2,"source_column":2,"source_line":7,"description":"Registro zero","original_description":"Registro zero","amount":0,"purchase_day_month":"19/02"}]','{}'),
('00000000-0000-4000-8000-000000000001',repeat('f',64),repeat('1',64),'synthetic-cycle','Fatura B.pdf','synthetic-b','Banco fictício','itau_visa','0002','2022-03-21','2022-04-01',40,1,
'[{"source_page":3,"source_column":1,"source_line":1,"description":"Serviço B","original_description":"Serviço B","amount":40,"original_category":"Emissor B"}]','{}');
SET LOCAL ROLE authenticated;
DO $test$
DECLARE j jsonb;k jsonb;before_detail jsonb;after_detail jsonb;cleaned jsonb;
BEGIN
 j:=public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a');
 k:=public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-b');
 IF public.lts_browser_expense_composition_v374('2022-04-02','2022-04-02','cycle-parent-b')->'rows'IS DISTINCT FROM j->'rows'
 THEN RAISE EXCEPTION 'Documented companion date lost with a one-day filter';END IF;
 IF j->>'status'<>'complete'OR(j->>'total')::numeric<>100 OR(k->>'total')::numeric<>25
 OR j->'rows'IS DISTINCT FROM k->'rows'OR(j->>'count')::int<>4 OR(j->>'nonzero_count')::int<>3
 OR(j->>'identified_total')::numeric<>115 OR(j->>'unexplained_total')::numeric<>0
 OR(j#>>'{reconciliation,original_total}')::numeric<>125 OR(j#>>'{reconciliation,adjustments_total}')::numeric<>-10
 OR(j#>>'{reconciliation,member_count}')::int<>3 OR(j#>>'{reconciliation,document_count}')::int<>2
 THEN RAISE EXCEPTION 'Multi-row multi-document cycle did not reconcile';END IF;
 IF j#>>'{rows,0,source,file}'<>'Fatura A.pdf'OR j#>>'{rows,3,source,file}'<>'Fatura B.pdf'
 OR j#>>'{rows,0,date}'IS NOT NULL OR j#>>'{rows,0,date_kind}'<>'purchase_day_month'
 OR j#>>'{rows,3,date}'<>'2022-03-21'OR j#>>'{rows,3,date_kind}'<>'document'
 OR j#>>'{rows,3,account_source}'<>'Visa Itaú'OR j#>>'{rows,0,source,sheet}'IS NOT NULL
 THEN RAISE EXCEPTION 'Document provenance, unstated year or card identity corrupted';END IF;
 before_detail:=public.lts_browser_expense_detail_v346('2022-04-01','2022-04-30');
 after_detail:=public.lts_browser_expense_detail_v374('2022-04-01','2022-04-30');
 IF(before_detail-'rows'-'version'-'revision')IS DISTINCT FROM(after_detail-'rows'-'version'-'revision')
 THEN RAISE EXCEPTION 'Pagination, total or filters changed';END IF;
 SELECT jsonb_agg(x-'composition'ORDER BY x->>'key')INTO cleaned FROM jsonb_array_elements(after_detail->'rows')x;
 IF cleaned IS DISTINCT FROM(SELECT jsonb_agg(x-'composition'ORDER BY x->>'key')FROM jsonb_array_elements(before_detail->'rows')x)
 THEN RAISE EXCEPTION 'Original row fields changed';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(after_detail->'rows')x WHERE x->>'key'IN('cycle-parent-a','cycle-parent-b')AND x#>>'{composition,status}'<>'complete')THEN RAISE EXCEPTION 'Available document still marked missing';END IF;
 k:=public.lts_browser_expense_scope_detail_v374('2022-04-01','2022-04-30','{"category":"original-scope"}',0,500,NULL);
 IF k->'scope'<>'{"category":"original-scope"}'::jsonb THEN RAISE EXCEPTION 'Scope not forwarded';END IF;
 IF has_table_privilege('authenticated','lts_history_private_v374.document','SELECT')
 OR has_function_privilege('authenticated','lts_history_private_v374.cycle_payload(uuid,text,jsonb,jsonb,jsonb,boolean)','EXECUTE')
 OR has_function_privilege('authenticated','lts_history_private_v374.decorate_detail(date,date,jsonb)','EXECUTE')
 THEN RAISE EXCEPTION 'Private source or arbitrary snapshot helper exposed';END IF;
END $test$;
RESET ROLE;
DO $negative$
DECLARE j jsonb;old_items jsonb;
BEGIN
 SELECT items INTO old_items FROM lts_history_private_v374.document WHERE source_sha256=repeat('d',64);
 UPDATE lts_history_private_v374.document SET items=jsonb_set(items,'{0,amount}','81')WHERE source_sha256=repeat('d',64);
 j:=public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a');
 IF j->>'status'<>'stale'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Incomplete source presented as closed';END IF;
 UPDATE lts_history_private_v374.document SET items=old_items WHERE source_sha256=repeat('d',64);
 UPDATE public.v346_financial SET amount=25.01 WHERE row_key='cycle-parent-b'AND user_id='00000000-0000-4000-8000-000000000001';
 j:=public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a');
 IF j->>'status'<>'stale'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Changed companion record ignored';END IF;
 UPDATE public.v346_financial SET amount=25 WHERE row_key='cycle-parent-b'AND user_id='00000000-0000-4000-8000-000000000001';
 UPDATE public.v346_financial SET coverage_mode='unrelated_refund'WHERE row_key='cycle-adjustment'AND user_id='00000000-0000-4000-8000-000000000001';
 IF public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a')->>'status'<>'stale'THEN RAISE EXCEPTION 'Unrelated refund accepted';END IF;
 UPDATE public.v346_financial SET coverage_mode='card_workbook_signed_adjustment_v235'WHERE row_key='cycle-adjustment'AND user_id='00000000-0000-4000-8000-000000000001';
 INSERT INTO public.v346_financial SELECT user_id,'unbound-new-positive',event_date,transaction_date,competence_month,1,category,account_source,source_table,'999',coverage_mode,management_group,management_subgroup,description FROM public.v346_financial WHERE row_key='cycle-parent-a'AND user_id='00000000-0000-4000-8000-000000000001';
 IF public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a')->>'status'<>'stale'THEN RAISE EXCEPTION 'New unmatched original row ignored';END IF;
 DELETE FROM public.v346_financial WHERE row_key='unbound-new-positive';
 BEGIN
  INSERT INTO lts_history_private_v374.document SELECT user_id,repeat('2',64),semantic_sha256,cycle_key,source_file,library_file_id,source_message_ref,issuer,family,'0099',document_date,due_date,reported_total,source_rows,items,validation FROM lts_history_private_v374.document WHERE source_sha256=repeat('d',64);
  RAISE EXCEPTION 'Semantic duplicate accepted';
 EXCEPTION WHEN unique_violation THEN NULL;END;
 BEGIN
  INSERT INTO lts_history_private_v374.document SELECT user_id,repeat('2',64),repeat('3',64),cycle_key,source_file,library_file_id,source_message_ref,issuer,family,billing_last4,document_date,due_date,reported_total,source_rows,items,validation FROM lts_history_private_v374.document WHERE source_sha256=repeat('d',64);
  RAISE EXCEPTION 'Two different variants of one card invoice accepted together';
 EXCEPTION WHEN unique_violation THEN NULL;END;
 IF public.lts_browser_expense_composition_v373('2022-04-01','2022-04-30','parent')IS DISTINCT FROM(SELECT prior.j FROM v374_old prior)
 OR public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','parent')IS DISTINCT FROM(SELECT prior.j FROM v374_old prior)
 THEN RAISE EXCEPTION 'Earlier source or reader replaced';END IF;
 IF(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id,row_key)FROM public.v346_financial x)IS DISTINCT FROM(SELECT prior.j FROM v374_before prior)THEN RAISE EXCEPTION 'Financial rows changed';END IF;
 IF EXISTS(SELECT 1 FROM v374_old_attrs a JOIN pg_proc p USING(oid)WHERE a.j IS DISTINCT FROM to_jsonb(p))THEN RAISE EXCEPTION 'Earlier functions changed';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE'%v374'AND prosecdef)
 OR has_function_privilege('anon','public.lts_browser_expense_composition_v374(date,date,text)','EXECUTE')THEN RAISE EXCEPTION 'Public elevation or anonymous access';END IF;
END $negative$;
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$DECLARE j jsonb;BEGIN
 j:=public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a');
 IF j->>'status'<>'missing'OR jsonb_array_length(j->'rows')<>0 THEN RAISE EXCEPTION 'Another owner can read documentary source';END IF;
END$$;
RESET ROLE;
SELECT set_config('app.synthetic_uid','',true);
DO $$BEGIN
 BEGIN PERFORM public.lts_browser_expense_composition_v374('2022-04-01','2022-04-30','cycle-parent-a');RAISE EXCEPTION 'Missing owner accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END$$;
SELECT jsonb_build_object('version',374,'pass',true,'multiple_original_rows',true,'multiple_documents',true,'source_years_and_cards_preserved',true,'companion_and_exhaustive_membership_guards',true,'available_detail_status',true,'legacy_precedence',true,'private_helpers_unexposed',true,'financial_rows_unchanged',true);
ROLLBACK;
''')
