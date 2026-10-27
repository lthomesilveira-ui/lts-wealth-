"""Actual presentation/detail/cache functions over synthetic canonical rows."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2]
print(r'''
BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
CREATE FUNCTION public.lts_browser_assert_user_v1()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT current_setting('request.jwt.claim.sub')::uuid$$;
CREATE FUNCTION public.lts_card_read_start_v269(uuid)RETURNS text LANGUAGE sql AS $$SELECT 'fixture'$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $3$$;
CREATE FUNCTION public.lts_v178_norm(text)RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower($1)$$;
CREATE FUNCTION public.lts_card_family_v226(text,text)RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT 'fixture'$$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,UNIQUE(user_id,kind,as_of,from_date,to_date));
CREATE TABLE public.v353_source(user_id uuid,row_key text,event_date date,transaction_date date,competence_month date,amount numeric,category text,beneficiary text,description text,account_source text,source_table text,source_ref text,coverage_mode text,raw_category text,raw_reference text,purchase_date date,identity_status text,management_group text,management_subgroup text,property_code text,property_component text);
CREATE TABLE public.v353_context(user_id uuid,source_table text,source_ref text,center_cost text);
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)RETURNS TABLE(row_key text,event_date date,transaction_date date,competence_month date,amount numeric,category text,beneficiary text,description text,account_source text,source_table text,source_ref text,coverage_mode text,raw_category text,raw_reference text,purchase_date date,identity_status text,management_group text,management_subgroup text,property_code text,property_component text)LANGUAGE sql STABLE AS $$SELECT row_key,event_date,transaction_date,competence_month,amount,category,beneficiary,description,account_source,source_table,source_ref,coverage_mode,raw_category,raw_reference,purchase_date,identity_status,management_group,management_subgroup,property_code,property_component FROM public.v353_source WHERE user_id=p_user_id AND event_date BETWEEN p_from AND p_to$$;
CREATE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid,p_from date,p_to date)RETURNS TABLE(source_table text,source_ref text,center_cost text)LANGUAGE sql STABLE AS $$SELECT source_table,source_ref,center_cost FROM public.v353_context WHERE user_id=p_user_id$$;
CREATE FUNCTION public.lts_browser_expenses_v229_engine_v251(date,date)RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('period',jsonb_build_object('from',$1,'to',$2),'summary',jsonb_build_object('selected_total',sum(amount),'rows',count(*)),'management_groups','[]'::jsonb)FROM public.lts_v229_expense_rows(public.lts_browser_assert_user_v1(),$1,$2)$$;
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,normalized_payload jsonb,institution_name text);
CREATE TABLE public.lts_card_history_source_audit_v235(user_id uuid,source_ref text,source_table text,event_date date,source_signed_amount numeric,source_file text,source_sheet text,source_rows jsonb,composition_status text,detail_rows integer,detail_total numeric,detail_difference numeric);
CREATE TABLE public.lts_workbook_identity_evidence_v232(user_id uuid,source_table text,source_ref text,original_category text,original_description text,source_sheet text,source_rows jsonb);
CREATE TABLE public.lts_card_history_item_v346(user_id uuid,parent_key text,amount numeric);
CREATE TABLE public.lts_card_history_parent_v346(user_id uuid,parent_key text,signature jsonb);
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
''')
u='00000000-0000-4000-8000-000000000001'
data=[]
for key,amount,cat,component,prop,beneficiary in [('a',150,'Farmácia',None,None,None),('b',-50,'Farmácia',None,None,None),('c',200,'Veículos - Tributos',None,None,None),('d',300,'Material Obra - O Parque','Obra e reforma','cipo396',None),('e',0,'Outros',None,None,None),('card',100,'Restaurantes',None,None,'Pessoa fictícia')]:
 data.append({'user_id':u,'row_key':key,'event_date':'2020-01-02','competence_month':'2020-01-01','amount':amount,'category':cat,'beneficiary':beneficiary,'description':'Compra fictícia '+key,'account_source':'Conta fictícia','source_table':'fixture_card'if key=='card'else'financial_events','source_ref':key,'coverage_mode':'card_invoice_aggregate_fallback'if key=='card'else'direct_cash','raw_category':cat,'raw_reference':'ref-'+key,'identity_status':'identified','management_group':cat,'management_subgroup':cat,'property_code':prop,'property_component':component})
print('INSERT INTO public.v353_source SELECT *FROM jsonb_populate_recordset(NULL::public.v353_source,$d$'+json.dumps(data)+'$d$);')
print(r'''
INSERT INTO public.v353_context VALUES('00000000-0000-4000-8000-000000000001','financial_events','d','Centro fictício'),('00000000-0000-4000-8000-000000000001','financial_events','e','A'),('00000000-0000-4000-8000-000000000001','financial_events','e','B');
CREATE TEMP TABLE v353_before_source AS SELECT to_jsonb(x)j FROM public.v353_source x;
''')
for name in ['v353_lts_card_history_signature_v346.sql','v353_lts_card_history_status_v346.sql','v353_report_original.sql']:print((R/'backend/qa/fixtures'/name).read_text()+';')
print('CREATE TEMP TABLE v353_before_report AS SELECT public.lts_browser_expenses_v229(\'2020-01-01\',\'2020-01-31\')j;')
for name in ['expense_presentation.sql','expense_detail.sql','expense_report.sql']:print((R/'backend/patches/v353'/name).read_text())
print(r'''
INSERT INTO public.lts_card_history_item_v346 VALUES('00000000-0000-4000-8000-000000000001','card',70),('00000000-0000-4000-8000-000000000001','card',30);
INSERT INTO public.lts_card_history_parent_v346 SELECT '00000000-0000-4000-8000-000000000001','card',public.lts_card_history_signature_v346('{"source_table":"fixture_card","source_ref":"card","event_date":"2020-01-02","period":"2020-01-01","amount":100}');
DO $test$DECLARE j jsonb;d jsonb;m text;BEGIN
 j:=public.lts_browser_expenses_v229('2020-01-01','2020-01-31');
 IF j-'presentation'IS DISTINCT FROM(SELECT b.j FROM v353_before_report b)THEN RAISE EXCEPTION 'Existing report changed';END IF;
 IF(j#>>'{presentation,summary,gross}')::numeric<>750 OR(j#>>'{presentation,summary,compensations}')::numeric<>50 OR(j#>>'{presentation,summary,net}')::numeric<>700 OR(j#>>'{presentation,summary,rows}')::int<>6 THEN RAISE EXCEPTION 'Signed totals mismatch: %',j;END IF;
 IF(SELECT count(*)FROM public.lts_expense_view_rows_v353('00000000-0000-4000-8000-000000000001','2020-01-01','2020-01-31'))<>6
 OR(SELECT center_cost FROM public.lts_expense_view_rows_v353('00000000-0000-4000-8000-000000000001','2020-01-01','2020-01-31')WHERE row_payload->>'row_key'='e')IS NOT NULL THEN RAISE EXCEPTION 'Ambiguous context duplicated or attributed';END IF;
 d:=public.lts_browser_expense_detail_v353('2020-01-01','2020-01-31','{"view":"tax"}');
 IF(d->>'row_count')::int<>1 OR(d->>'total')::numeric<>200 OR d#>'{rows,0,property_code}'IS DISTINCT FROM'null'::jsonb OR d#>'{rows,0,beneficiary}'IS DISTINCT FROM'null'::jsonb THEN RAISE EXCEPTION 'Tax view guessed an asset or person';END IF;
 d:=public.lts_browser_expense_detail_v353('2020-01-01','2020-01-31','{"sign":"compensations"}');
 IF(d->>'total')::numeric<>-50 OR d#>>'{rows,0,original_category}'<>'Farmácia'THEN RAISE EXCEPTION 'Refund lost its category or sign';END IF;
 d:=public.lts_browser_expense_detail_v353('2020-01-01','2020-01-31','{"category":"Restaurantes"}');
 IF d#>>'{rows,0,composition,status}'<>'complete'OR(d#>>'{rows,0,composition,count}')::int<>2 THEN RAISE EXCEPTION 'Existing composition lost';END IF;
 d:=public.lts_browser_expense_detail_v353('2020-01-01','2020-01-31','{}',0,2);
 IF(d->>'next_offset')::int<>2 OR jsonb_array_length(d->'rows')<>2 OR(d->>'row_count')::int<>6 THEN RAISE EXCEPTION 'Pagination cut the inventory';END IF;
 j:=public.lts_browser_expense_hierarchy_v353('2020-01-01','2020-01-31','{"view":"property"}');
 IF(j#>>'{summary,net}')::numeric<>700 OR jsonb_array_length(j->'nodes')<>2 THEN RAISE EXCEPTION 'Property perspective changes money';END IF;
 j:=public.lts_browser_expense_hierarchy_v353('2020-01-01','2020-01-31','{"person":"__missing__"}');
 IF(j#>>'{summary,net}')::numeric<>600 OR(j#>>'{summary,rows}')::int<>5 THEN RAISE EXCEPTION 'Missing person rows disappeared';END IF;
 BEGIN PERFORM public.lts_browser_expense_hierarchy_v353('2020-01-01','2020-01-31','{"user_id":"other"}');EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS NULL THEN RAISE EXCEPTION 'Arbitrary owner filter accepted';END IF;
 IF EXISTS((SELECT j FROM v353_before_source EXCEPT ALL SELECT to_jsonb(x)FROM public.v353_source x)UNION ALL(SELECT to_jsonb(x)FROM public.v353_source x EXCEPT ALL SELECT j FROM v353_before_source))THEN RAISE EXCEPTION 'Source rows changed';END IF;
 IF has_function_privilege('anon','public.lts_browser_expense_detail_v353(date,date,jsonb,integer,integer,text)','EXECUTE')OR has_function_privilege('authenticated','public.lts_expense_view_rows_v353(uuid,date,date)','EXECUTE')THEN RAISE EXCEPTION 'Private helper privilege leak';END IF;
END$test$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
DO $$DECLARE j jsonb;BEGIN j:=public.lts_browser_expense_hierarchy_v353('2020-01-01','2020-01-31');IF(j#>>'{summary,rows}')::int<>0 THEN RAISE EXCEPTION 'Other owner data leaked';END IF;END$$;
SELECT jsonb_build_object('pass',true,'version',353,'canonical_sources_unchanged',true,'signed_totals_and_filters',true,'ambiguous_context_not_attributed',true,'composition_preserved',true,'paging_complete',true,'cross_owner_isolated',true);
ROLLBACK;
''')
