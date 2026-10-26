"""Public synthetic PostgreSQL contracts; no owner financial data."""
from pathlib import Path
r=Path(__file__).resolve().parents[2]
print(r'''
BEGIN;
CREATE TABLE public.v346_financial(user_id uuid,row_key text,event_date date,transaction_date date,competence_month date,amount numeric,category text,account_source text,source_table text,source_ref text,coverage_mode text,management_group text,management_subgroup text);
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $$BEGIN IF nullif(current_setting('app.synthetic_uid',true),'') IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501';END IF;RETURN current_setting('app.synthetic_uid')::uuid;END$$;
CREATE FUNCTION public.lts_v229_expense_rows(p_uid uuid,p_from date,p_to date) RETURNS SETOF public.v346_financial LANGUAGE sql SET search_path='' AS $$SELECT * FROM public.v346_financial WHERE user_id=p_uid AND event_date BETWEEN p_from AND p_to$$;
CREATE FUNCTION public.lts_browser_expense_detail_v229(p_from date,p_to date,p_group text DEFAULT NULL,p_subgroup text DEFAULT NULL,p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1();j jsonb;
BEGIN IF p_from>p_to OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'invalid detail range';END IF;
SELECT jsonb_build_object('version','prior-reader','total',sum(amount),'row_count',count(*),'rows',jsonb_agg(to_jsonb(x)-'user_id'-'row_key'-'competence_month'||jsonb_build_object('key',row_key,'period',competence_month)),'revision','synthetic-stable','offset',0,'next_offset',NULL)INTO j FROM public.lts_v229_expense_rows(u,p_from,p_to)x WHERE p_group IS NULL OR management_group=p_group;RETURN j;END$$;
INSERT INTO public.v346_financial VALUES('00000000-0000-4000-8000-000000000001','parent',date '2022-04-01',date '2022-04-01',date '2022-04-01',100,'Original category','Synthetic card','synthetic_card','1','card_category_allocated_history','Original category','Original category');
INSERT INTO public.v346_financial SELECT '00000000-0000-4000-8000-000000000002',row_key,event_date,transaction_date,competence_month,amount,category,account_source,source_table,source_ref,coverage_mode,management_group,management_subgroup FROM public.v346_financial;
''')
print((r/'backend/patches/v346/history_composition.sql').read_text())
print(r'''
SELECT set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000001',true);
INSERT INTO public.lts_card_history_parent_v346 SELECT user_id,row_key,public.lts_card_history_signature_v346(to_jsonb(x)),'{}',now()FROM public.v346_financial x WHERE user_id=current_setting('app.synthetic_uid')::uuid;
INSERT INTO public.lts_card_history_item_v346 SELECT '00000000-0000-4000-8000-000000000001','parent',repeat('a',64),'Synthetic.xlsx','Synthetic',i,date '2022-04-01',date '2022-04-01',amount,amount,'Original text','Original category','Synthetic card','1234',NULL,NULL FROM(VALUES(1,70),(2,35),(3,-5),(4,0))s(i,amount);
CREATE TEMP TABLE v346_before AS SELECT jsonb_agg(to_jsonb(x) ORDER BY user_id)j FROM public.v346_financial x;
DO $test$
DECLARE p jsonb;before_detail jsonb;after_detail jsonb;cleaned jsonb;
BEGIN
 p:=public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');
 IF p->>'status'<>'complete'OR p->>'identified_total'<>'100.00'OR(p->>'count')::int<>4 OR(p->>'nonzero_count')::int<>3 THEN RAISE EXCEPTION 'complete signed source lost';END IF;
 before_detail:=public.lts_browser_expense_detail_v229(date '2022-04-01',date '2022-04-30');after_detail:=public.lts_browser_expense_detail_v346(date '2022-04-01',date '2022-04-30');
 SELECT jsonb_agg(x-'composition')INTO cleaned FROM jsonb_array_elements(after_detail->'rows')x;
 IF(before_detail-'rows'-'version')IS DISTINCT FROM(after_detail-'rows'-'version')OR cleaned IS DISTINCT FROM before_detail->'rows'THEN RAISE EXCEPTION 'original reader changed';END IF;
 BEGIN INSERT INTO public.lts_card_history_item_v346 SELECT * FROM public.lts_card_history_item_v346 LIMIT 1;RAISE EXCEPTION 'duplicate accepted';EXCEPTION WHEN unique_violation THEN NULL;END;
 DELETE FROM public.lts_card_history_item_v346 WHERE source_row=2;
 p:=public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');IF p->>'status'<>'partial'OR(p->>'residual_total')::numeric<>35 THEN RAISE EXCEPTION 'partial not separated';END IF;
 UPDATE public.lts_card_history_parent_v346 SET signature=signature||'{"amount":101}';
 p:=public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');IF p->>'status'<>'stale'OR jsonb_array_length(p->'rows')<>0 THEN RAISE EXCEPTION 'stale exposed';END IF;
 DELETE FROM public.lts_card_history_item_v346;DELETE FROM public.lts_card_history_parent_v346;
 p:=public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');IF p->>'status'<>'missing'OR(p->>'residual_total')::numeric<>100 THEN RAISE EXCEPTION 'missing hidden';END IF;
 PERFORM set_config('app.synthetic_uid','00000000-0000-4000-8000-000000000002',true);
 p:=public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');IF jsonb_array_length(p->'rows')<>0 THEN RAISE EXCEPTION 'cross-owner source leak';END IF;
 PERFORM set_config('app.synthetic_uid','',true);
 BEGIN PERFORM public.lts_browser_expense_composition_v346(date '2022-04-01',date '2022-04-30','parent');RAISE EXCEPTION 'missing identity accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF has_table_privilege('authenticated','public.lts_card_history_item_v346','SELECT')OR has_function_privilege('anon','public.lts_browser_expense_composition_v346(date,date,text)','EXECUTE')THEN RAISE EXCEPTION 'access broadened';END IF;
 IF(SELECT jsonb_agg(to_jsonb(x) ORDER BY user_id)FROM public.v346_financial x)IS DISTINCT FROM(SELECT j FROM v346_before)THEN RAISE EXCEPTION 'financial events changed';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'version',346,'signed_and_zero_records',true,'partial_and_missing_separate',true,'stale_hidden',true,'owner_isolation',true,'duplicate_rejected',true,'totals_unchanged',true,'no_financial_events',true)receipt;
ROLLBACK;
''')
