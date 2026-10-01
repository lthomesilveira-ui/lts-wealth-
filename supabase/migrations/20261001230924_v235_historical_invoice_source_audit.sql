-- Owner-scoped source evidence. Private import values are intentionally separate.
CREATE TABLE public.lts_card_history_evidence_v235 (
 user_id uuid NOT NULL REFERENCES auth.users(id),
 source_table text NOT NULL CHECK(source_table IN ('evento_base','historico_analitico')),
 source_ref text NOT NULL,
 event_date date NOT NULL,
 reference_month date NOT NULL,
 bank text NOT NULL,
 family text NOT NULL,
 card_name text NOT NULL,
 description text NOT NULL,
 observed_amount numeric NOT NULL CHECK(observed_amount>0),
 signed_amount numeric NOT NULL,
 composition_status text NOT NULL CHECK(composition_status IN ('aggregate_only','partial_source')),
 workbook_evidence jsonb NOT NULL CHECK(jsonb_typeof(workbook_evidence)='array' AND jsonb_array_length(workbook_evidence)>=2),
 verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref),
 CHECK(round(abs(signed_amount),2)=round(observed_amount,2)),
 CHECK(reference_month=date_trunc('month',reference_month)::date)
);
CREATE INDEX lts_card_history_evidence_v235_cycle ON public.lts_card_history_evidence_v235(user_id,family,reference_month);
ALTER TABLE public.lts_card_history_evidence_v235 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lts_card_history_evidence_v235 FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.lts_card_history_evidence_v235 TO service_role;

CREATE TABLE public.lts_card_history_lines_v235 (
 user_id uuid NOT NULL REFERENCES auth.users(id),
 family text NOT NULL,
 reference_month date NOT NULL,
 source_file text NOT NULL,
 source_hash text NOT NULL,
 source_sheet text NOT NULL,
 source_row integer NOT NULL CHECK(source_row>0),
 source_date date NOT NULL,
 category text NOT NULL,
 amount numeric NOT NULL,
 last4 text,
 corroboration jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_hash,source_sheet,source_row),
 CHECK(reference_month=date_trunc('month',source_date)::date)
);
CREATE INDEX lts_card_history_lines_v235_cycle ON public.lts_card_history_lines_v235(user_id,family,reference_month);
ALTER TABLE public.lts_card_history_lines_v235 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lts_card_history_lines_v235 FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.lts_card_history_lines_v235 TO service_role;

-- Keep the prior reader as a reversible baseline. Correct only individually
-- evidenced aggregate signs; amounts, dates and raw source rows stay intact.
DO $capture$
DECLARE original text;
BEGIN
 IF to_regprocedure('public.lts_expense_effective_rows_v234_baseline(uuid,date,date)') IS NULL THEN
  original:=pg_get_functiondef('public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure);
  EXECUTE replace(original,'public.lts_expense_effective_rows_v176(', 'public.lts_expense_effective_rows_v234_baseline(');
 END IF;
END $capture$;
REVOKE ALL ON FUNCTION public.lts_expense_effective_rows_v234_baseline(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_expense_effective_rows_v234_baseline(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid,p_from date DEFAULT '2013-10-10'::date,p_to date DEFAULT CURRENT_DATE)
RETURNS TABLE(event_date date,transaction_date date,competence_month date,amount numeric,category text,center_cost text,counterparty text,origin_type text,origin_name text,source_table text,source_ref text,coverage_mode text,is_property boolean,is_financing boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
 SELECT r.event_date,r.transaction_date,r.competence_month,coalesce(e.signed_amount,r.amount),r.category,r.center_cost,r.counterparty,
 r.origin_type,r.origin_name,r.source_table,r.source_ref,r.coverage_mode,r.is_property,r.is_financing
 FROM public.lts_expense_effective_rows_v234_baseline(p_user_id,p_from,p_to) r
 LEFT JOIN public.lts_card_history_evidence_v235 e ON e.user_id=p_user_id
 AND r.coverage_mode='card_invoice_aggregate_fallback' AND e.source_table=r.source_table AND e.source_ref=r.source_ref
 AND e.event_date=r.event_date AND e.reference_month=r.competence_month AND round(e.observed_amount,2)=round(r.amount,2)
$function$;
REVOKE ALL ON FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_card_history_inventory_v235(p_from date,p_to date,p_offset integer DEFAULT 0,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<'2013-10-10'::date OR p_to>current_date OR p_offset IS NULL OR p_offset<0 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'invalid inventory range';
 END IF;
 WITH records AS MATERIALIZED (
  SELECT r.source_table,r.source_ref,r.event_date,r.competence_month,r.amount,
   coalesce(e.bank,'Banco a confirmar') bank,e.family,coalesce(e.card_name,r.account_source) card_name,
   coalesce(e.composition_status,'audit_pending') composition_status,
   e.signed_amount<0 AND e.signed_amount<>e.observed_amount sign_corrected,e.verified_at
  FROM public.lts_v229_expense_rows(u,p_from,p_to) r
  LEFT JOIN public.lts_card_history_evidence_v235 e ON e.user_id=u AND e.source_table=r.source_table AND e.source_ref=r.source_ref
   AND e.event_date=r.event_date AND e.reference_month=r.competence_month AND e.signed_amount=round(r.amount,2)
  WHERE r.coverage_mode='card_invoice_aggregate_fallback'
 ), cycles AS MATERIALIZED (
  SELECT bank,family,card_name,competence_month reference_month,round(sum(amount),2) amount,count(*) record_count,
   round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) charges,
   round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) credits,
   (array_agg(source_table ORDER BY event_date,source_ref))[1] source_table,
   (array_agg(source_ref ORDER BY event_date,source_ref))[1] source_ref,
   min(event_date) event_date,
   CASE WHEN bool_or(composition_status='audit_pending') THEN 'audit_pending'
     WHEN bool_or(composition_status='partial_source') THEN 'partial_source' ELSE 'aggregate_only' END composition_status,
   max(verified_at) verified_at
  FROM records GROUP BY bank,family,card_name,competence_month
 ), page AS MATERIALIZED (SELECT * FROM cycles ORDER BY reference_month DESC,card_name,bank OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','card-history-inventory-v235','from',p_from,'to',p_to,'offset',p_offset,
  'summary',jsonb_build_object('record_count',(SELECT count(*) FROM records),'cycle_count',(SELECT count(*) FROM cycles),
   'total',(SELECT round(coalesce(sum(amount),0),2) FROM records),
   'charges',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) FROM records),
   'credits',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) FROM records),
   'sign_corrections',(SELECT count(*) FROM records WHERE sign_corrected),
   'aggregate_only_cycles',(SELECT count(*) FROM cycles WHERE composition_status='aggregate_only'),
   'partial_source_cycles',(SELECT count(*) FROM cycles WHERE composition_status='partial_source'),
   'audit_pending_cycles',(SELECT count(*) FROM cycles WHERE composition_status='audit_pending')),
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM cycles) THEN p_offset+p_limit END,
  'cycles',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY reference_month DESC,card_name,bank) FROM page p),'[]'::jsonb)
 ) INTO result;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_card_history_inventory_v235(date,date,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_history_inventory_v235(date,date,integer,integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_card_history_record_v235(p_source_table text,p_source_ref text,p_event_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); e public.lts_card_history_evidence_v235%ROWTYPE; result jsonb;
BEGIN
 IF p_source_table IS NULL OR p_source_ref IS NULL OR p_event_date IS NULL THEN RAISE EXCEPTION 'invalid record'; END IF;
 SELECT * INTO e FROM public.lts_card_history_evidence_v235 x WHERE x.user_id=u AND x.source_table=p_source_table AND x.source_ref=p_source_ref AND x.event_date=p_event_date;
 IF NOT FOUND THEN RAISE EXCEPTION 'record audit unavailable'; END IF;
 WITH current_rows AS MATERIALIZED (
  SELECT r.* FROM public.lts_v229_expense_rows(u,e.reference_month,least(current_date,(e.reference_month+interval '1 month - 1 day')::date)) r
  WHERE r.coverage_mode='card_invoice_aggregate_fallback'
 ), records AS MATERIALIZED (
  SELECT a.*,r.amount current_amount FROM public.lts_card_history_evidence_v235 a
  JOIN current_rows r ON r.source_table=a.source_table AND r.source_ref=a.source_ref AND r.event_date=a.event_date AND round(r.amount,2)=a.signed_amount
  WHERE a.user_id=u AND a.family=e.family AND a.reference_month=e.reference_month
 ), lines AS MATERIALIZED (
  SELECT * FROM public.lts_card_history_lines_v235 l WHERE l.user_id=u AND l.family=e.family AND l.reference_month=e.reference_month
 )
 SELECT jsonb_build_object('version','card-history-record-v235','bank',e.bank,'card_name',e.card_name,'family',e.family,
  'reference_month',e.reference_month,'composition_status',e.composition_status,
  'record',jsonb_build_object('source_table',e.source_table,'source_ref',e.source_ref,'event_date',e.event_date,'description',e.description,
   'amount',e.signed_amount,'original_report_amount',e.observed_amount,'sign_corrected',e.signed_amount<>e.observed_amount,
   'workbook_evidence',e.workbook_evidence,'verified_at',e.verified_at),
  'cycle_total',(SELECT round(sum(current_amount),2) FROM records),
  'cycle_records',coalesce((SELECT jsonb_agg(jsonb_build_object('source_table',a.source_table,'source_ref',a.source_ref,'date',a.event_date,'description',a.description,
   'amount',a.current_amount,'kind',CASE WHEN a.current_amount<0 THEN 'credit_or_adjustment' ELSE 'payment' END,'workbook_evidence',a.workbook_evidence)
   ORDER BY a.event_date,a.source_ref) FROM records a),'[]'::jsonb),
  'detail_total',(SELECT round(sum(amount),2) FROM lines),
  'detail_difference',(SELECT round(sum(amount),2) FROM lines)-(SELECT round(sum(current_amount),2) FROM records),
  'detail_rows',(SELECT count(*) FROM lines),'nonzero_detail_rows',(SELECT count(*) FROM lines WHERE amount<>0),
  'items',coalesce((SELECT jsonb_agg(jsonb_build_object('category',l.category,'amount',l.amount,'source_file',l.source_file,'source_sheet',l.source_sheet,
   'source_row',l.source_row,'source_date',l.source_date,'last4',l.last4,'corroboration',l.corroboration)
   ORDER BY l.source_row) FROM lines l),'[]'::jsonb),
  'source_note',CASE WHEN e.composition_status='partial_source' THEN 'Composição da planilha disponível. A diferença mantém a conciliação pendente; os itens não são somados novamente às despesas.'
   ELSE 'Pagamento e ajustes conferidos com as planilhas originais. A composição das compras não foi localizada nas fontes disponíveis.' END
 ) INTO result;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'cycle_records') x WHERE x->>'source_table'=e.source_table AND x->>'source_ref'=e.source_ref) THEN
  RAISE EXCEPTION 'record changed after audit';
 END IF;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_card_history_record_v235(text,text,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_history_record_v235(text,text,date) TO authenticated,service_role;
