-- A cash receipt already netted against a documentary expense must not also
-- become monthly income. Keep the original expense, bank posting and Flow.
CREATE OR REPLACE FUNCTION public.lts_income_expense_offset_v397(p_user_id uuid,p_row jsonb)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $function$
WITH eligible AS MATERIALIZED(
 SELECT e.user_id,e.evidence_date,e.amount,e.metadata->>'source_table' source_table,
 e.metadata->>'source_ref' source_ref
 FROM public.lts_reconciliation_evidence e
 JOIN public.lts_open_finance_staging s ON s.id::text=e.metadata->>'bank_staging_id' AND s.user_id=e.user_id
 JOIN public.lts_expense_documentary_amount_override o ON o.id::text=e.metadata->>'expense_override_id' AND o.user_id=e.user_id
 JOIN public.lts_reconciliation_evidence h ON h.id::text=e.metadata->>'cash_sign_evidence_id' AND h.user_id=e.user_id
 JOIN public.evento_base b ON b.usuario_id=e.user_id AND b.idx::text=e.metadata->>'source_ref'
 WHERE e.user_id=p_user_id AND e.evidence_type='income_expense_offset_v397' AND e.status='documented'
 AND e.metadata->>'version'='documented-negative-expense-income-offset-v397'
 AND e.metadata->>'basis'='received_bank_credit_already_nets_documented_expense'
 AND e.metadata->>'source_table'='evento_base' AND e.amount>0
 AND e.evidence_date::text=p_row->>'event_date' AND e.account=p_row->>'account'
 AND to_jsonb(e.amount)=p_row->'signed_amount'
 AND p_row->'internal_transfer' IS DISTINCT FROM 'true'::jsonb
 AND p_row->'excluded_from_spend' IS DISTINCT FROM 'true'::jsonb
 AND ((p_row->>'source'='legacy_fix86' AND p_row->>'source_ref'=e.metadata->>'flow_source_ref')
 OR(p_row->>'source'='open_finance' AND p_row->>'open_finance_id'=s.id::text))
 AND e.metadata->>'flow_source_ref'='evento_base:'||(e.metadata->>'source_ref')
 AND s.resource_type='transaction' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
 AND s.signed_amount=e.amount AND s.posting_date=e.evidence_date
 AND s.raw_hash=e.metadata->>'bank_raw_hash' AND s.raw_hash~'^[0-9a-f]{64}$'
 AND s.provider_record_id=e.metadata->>'bank_provider_record_id'
 AND s.provider_account_ref=e.metadata->>'bank_provider_account_ref'
 AND nullif(s.provider_account_ref,'') IS NOT NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.normalized_payload->>'date'=e.evidence_date::text
 AND s.raw_payload->>'status'='POSTED' AND s.raw_payload->>'type'='CREDIT'
 AND s.raw_payload->>'currencyCode'='BRL' AND s.raw_payload->'amount'=to_jsonb(e.amount)
 AND e.account=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND o.source_table=e.metadata->>'source_table' AND o.source_ref=e.metadata->>'source_ref'
 AND o.status='documented' AND o.event_date=e.evidence_date
 AND o.documented_signed_amount=-e.amount AND o.imported_amount=e.amount
 AND b.dados=e.metadata->'source_event_data' AND b.dados->>'dia'=e.evidence_date::text
 AND b.dados->>'efeito'='saida' AND b.dados->'valor'=to_jsonb(e.amount)
 AND h.evidence_type='historical_workbook_cash_sign' AND h.status='documented'
 AND h.evidence_date=e.evidence_date AND h.amount=e.amount
 AND h.metadata->>'target_flow_source_ref'=e.metadata->>'flow_source_ref'
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(h.metadata->'workbook_evidence','[]'))w
 WHERE w->>'sha256'=e.metadata->>'workbook_sha256'
 AND w->>'row'=e.metadata->>'workbook_row'
 AND CASE WHEN w->>'source_amount'~'^-[0-9]+(\.[0-9]+)?$' THEN(w->>'source_amount')::numeric=-e.amount ELSE false END)
)
SELECT (SELECT count(*)FROM eligible)=1 AND EXISTS(
 SELECT 1 FROM eligible e
 CROSS JOIN LATERAL public.lts_v229_expense_rows(e.user_id,e.evidence_date,e.evidence_date)x
 WHERE x.source_table=e.source_table AND x.source_ref=e.source_ref
 AND x.event_date=e.evidence_date AND x.amount=-e.amount
 AND x.coverage_mode='documentary_amount_override'
 GROUP BY e.source_table,e.source_ref HAVING count(*)=1)
$function$;
REVOKE ALL ON FUNCTION public.lts_income_expense_offset_v397(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_income_expense_offset_v397(uuid,jsonb) TO service_role;

DO $patch$
DECLARE d text:=pg_get_functiondef('lts_income_private.rows_v296(uuid,date,date)'::regprocedure);
 marker text:='WHERE NOT public.lts_income_expense_offset_v397(p_user_id,x)';
BEGIN
 IF position(marker IN d)>0 THEN RETURN;END IF;
 IF md5(d)<>'2cc3c7d1d235a33b4c595123b839de1b' THEN RAISE EXCEPTION 'Income reader changed; inspect before applying V397';END IF;
 IF length(d)-length(replace(d,'FROM unique_rows;',''))<>length('FROM unique_rows;') THEN RAISE EXCEPTION 'Income exclusion point is ambiguous';END IF;
 d:=replace(d,'FROM unique_rows;','FROM unique_rows '||marker||';');
 EXECUTE d;
END $patch$;
