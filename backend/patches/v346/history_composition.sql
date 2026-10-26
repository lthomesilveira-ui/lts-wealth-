-- Read-only composition beneath an existing expense. These tables are never
-- inputs of the financial ledger, expense totals, invoices, cash or forecasts.
CREATE TABLE public.lts_card_history_parent_v346 (
 user_id uuid NOT NULL, parent_key text NOT NULL,
 signature jsonb NOT NULL CHECK(jsonb_typeof(signature)='object'),
 provenance jsonb NOT NULL CHECK(jsonb_typeof(provenance)='object'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,parent_key)
);
CREATE TABLE public.lts_card_history_item_v346 (
 user_id uuid NOT NULL, parent_key text NOT NULL,
 source_hash text NOT NULL CHECK(source_hash ~ '^[0-9a-f]{64}$'),
 source_file text NOT NULL, source_sheet text NOT NULL,
 source_row integer NOT NULL CHECK(source_row>0),
 source_date date NOT NULL, cycle_date date,
 source_amount numeric NOT NULL, amount numeric NOT NULL,
 original_description text NOT NULL, original_category text NOT NULL,
 card_label text NOT NULL, last4 text, formula text,
 document jsonb CHECK(document IS NULL OR jsonb_typeof(document)='object'),
 PRIMARY KEY(user_id,source_hash,source_sheet,source_row),
 FOREIGN KEY(user_id,parent_key) REFERENCES public.lts_card_history_parent_v346(user_id,parent_key)
);
CREATE INDEX lts_card_history_item_v346_parent ON public.lts_card_history_item_v346(user_id,parent_key);
ALTER TABLE public.lts_card_history_parent_v346 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_card_history_item_v346 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_history_parent_v346,public.lts_card_history_item_v346 FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.lts_card_history_parent_v346,public.lts_card_history_item_v346 TO service_role;
CREATE POLICY service_only ON public.lts_card_history_parent_v346 TO service_role USING(true) WITH CHECK(true);
CREATE POLICY service_only ON public.lts_card_history_item_v346 TO service_role USING(true) WITH CHECK(true);

-- Small immutable identity: later source/category readers remain authoritative.
CREATE FUNCTION public.lts_card_history_signature_v346(p_row jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT jsonb_build_object('source_table',p_row->>'source_table','source_ref',p_row->>'source_ref',
 'event_date',p_row->>'event_date','period',coalesce(p_row->>'period',p_row->>'competence_month'),
 'amount',p_row->'amount');
$$;
REVOKE ALL ON FUNCTION public.lts_card_history_signature_v346(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_history_signature_v346(jsonb) TO service_role;

CREATE FUNCTION public.lts_card_history_status_v346(p_bound boolean,p_exists boolean,p_amount numeric,p_sum numeric,p_count bigint) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_exists AND NOT coalesce(p_bound,false) THEN 'stale'
 WHEN coalesce(p_count,0)=0 THEN 'missing'
 WHEN round(p_sum,2)=round(p_amount,2) THEN 'complete'
 WHEN p_amount>0 AND p_sum>=0 AND p_sum<p_amount THEN 'partial'
 ELSE 'difference' END;
$$;
REVOKE ALL ON FUNCTION public.lts_card_history_status_v346(boolean,boolean,numeric,numeric,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_history_status_v346(boolean,boolean,numeric,numeric,bigint) TO service_role;

CREATE FUNCTION public.lts_browser_expense_detail_v346(p_from date,p_to date,p_group text DEFAULT NULL,p_subgroup text DEFAULT NULL,p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); base jsonb; result_rows jsonb;
BEGIN
 -- The established reader owns periods, classification, pagination and totals.
 base:=public.lts_browser_expense_detail_v229(p_from,p_to,p_group,p_subgroup,p_offset,p_limit,p_query);
 WITH items AS MATERIALIZED(SELECT e.r,e.ord FROM jsonb_array_elements(base->'rows') WITH ORDINALITY e(r,ord)),
 summary AS MATERIALIZED(
 SELECT c.parent_key,count(*) n,count(*) FILTER(WHERE c.amount<>0) nonzero,sum(c.amount) amount
 FROM public.lts_card_history_item_v346 c JOIN items i ON i.r->>'key'=c.parent_key
 WHERE c.user_id=u GROUP BY c.parent_key
 )
 SELECT coalesce(jsonb_agg(i.r || CASE WHEN i.r->>'coverage_mode' IN
 ('card_category_allocated_history','card_category_allocated_workbook_v176','card_invoice_aggregate_fallback')
 THEN jsonb_build_object('composition',jsonb_build_object(
 'status',public.lts_card_history_status_v346(p.signature=public.lts_card_history_signature_v346(i.r),p.parent_key IS NOT NULL,(i.r->>'amount')::numeric,s.amount,s.n),
 'count',coalesce(s.n,0),'nonzero_count',coalesce(s.nonzero,0))) ELSE '{}'::jsonb END ORDER BY i.ord),'[]'::jsonb)
 INTO result_rows FROM items i LEFT JOIN public.lts_card_history_parent_v346 p ON p.user_id=u AND p.parent_key=i.r->>'key'
 LEFT JOIN summary s ON s.parent_key=i.r->>'key';
 RETURN (base-'rows') || jsonb_build_object('rows',result_rows,'version','expense-detail-v346');
END;
$$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_detail_v346(date,date,text,text,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_detail_v346(date,date,text,text,integer,integer,text) TO authenticated,service_role;

CREATE FUNCTION public.lts_browser_expense_composition_v346(p_from date,p_to date,p_row_key text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); r record; p record; result jsonb; found_parent boolean;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to>current_date OR p_from<date '2013-10-10'
 OR nullif(trim(p_row_key),'') IS NULL OR length(p_row_key)>1000 THEN RAISE EXCEPTION 'invalid composition range';END IF;
 SELECT * INTO r FROM public.lts_v229_expense_rows(u,p_from,p_to) x WHERE x.row_key=p_row_key;
 IF NOT FOUND OR r.coverage_mode NOT IN ('card_category_allocated_history','card_category_allocated_workbook_v176','card_invoice_aggregate_fallback')
 THEN RAISE EXCEPTION 'composition not available in this period';END IF;
 SELECT * INTO p FROM public.lts_card_history_parent_v346 WHERE user_id=u AND parent_key=p_row_key;
 found_parent:=FOUND;
 IF found_parent AND p.signature IS DISTINCT FROM public.lts_card_history_signature_v346(to_jsonb(r)) THEN
  RETURN jsonb_build_object('status','stale','total',round(r.amount,2),'identified_total',0,'residual_total',round(r.amount,2),
   'count',0,'nonzero_count',0,'rows','[]'::jsonb,'category',r.category,'period',r.competence_month,'key',r.row_key);
 END IF;
 WITH source AS MATERIALIZED(SELECT * FROM public.lts_card_history_item_v346 WHERE user_id=u AND parent_key=p_row_key),
 totals AS(SELECT count(*) n,count(*) FILTER(WHERE amount<>0) nonzero,coalesce(sum(amount),0) amount FROM source)
 SELECT jsonb_build_object('version','expense-composition-v346','key',r.row_key,'category',r.category,'group',r.management_group,
 'period',r.competence_month,'event_date',r.event_date,'total',round(r.amount,2),'identified_total',round(t.amount,2),
 'residual_total',round(r.amount-t.amount,2),'count',t.n,'nonzero_count',t.nonzero,
 'status',public.lts_card_history_status_v346(true,found_parent,r.amount,t.amount,t.n),
 'precision_note',t.n>0 AND r.amount<>t.amount AND round(r.amount,2)=round(t.amount,2),
 'rows',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'key',c.source_hash||':'||c.source_sheet||':'||c.source_row,'description',c.original_description,
  'category',r.category,'original_category',c.original_category,'amount',c.amount,'original_amount',c.source_amount,
  'source_date',c.source_date,'date',coalesce(c.document->>'purchase_date',c.source_date::text),
  'date_kind',CASE WHEN c.document->>'purchase_date' IS NOT NULL THEN 'purchase' ELSE 'source' END,
  'period',r.competence_month,'cycle_date',c.cycle_date,'account_source',c.card_label,'last4',c.last4,
  'source',jsonb_build_object('file',c.source_file,'sha256',c.source_hash,'sheet',c.source_sheet,'row',c.source_row,
   'date_cell','C'||c.source_row,'description_cell','B'||c.source_row,'amount_cell','D'||c.source_row,
   'amount_formula',c.formula,'description',c.original_description,'amount',c.source_amount,'date',c.source_date),
  'document',c.document
 ) ORDER BY c.source_sheet,c.source_row) FROM source c),'[]'::jsonb)) INTO result FROM totals t;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_composition_v346(date,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_composition_v346(date,date,text) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
