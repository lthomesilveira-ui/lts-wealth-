CREATE OR REPLACE FUNCTION public.lts_fgts_position_evidence_v386(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH position AS MATERIALIZED (
 SELECT value_brl,as_of_date,metadata
 FROM public.asset_positions
 WHERE user_id=p_user_id AND asset_type='FGTS' AND as_of_date<=p_as_of
 ORDER BY as_of_date DESC,created_at DESC,id DESC LIMIT 1
), policy AS MATERIALIZED (
 SELECT settings#>'{liquidity_movements_v242,fgts}' j
 FROM public.app_settings WHERE user_id=p_user_id
), receipt AS MATERIALIZED (
 SELECT s.posting_date,s.signed_amount,
   public.lts_bank_fgts_combined_receipt_v261(p_user_id,s.id) evidence
 FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='transaction'
   AND s.institution_code='341' AND s.currency='BRL'
   AND s.provider_deleted_at IS NULL AND s.posting_date<=p_as_of
   AND s.posting_date=(SELECT (j->>'receipt_date')::date FROM policy)
   AND s.signed_amount=(SELECT (j->>'total_brl')::numeric FROM policy)
), confirmed AS (
 SELECT count(*) n,min(posting_date) receipt_date,max(signed_amount) amount
 FROM receipt WHERE evidence IS NOT NULL
), state AS (
 SELECT p.*,
   (SELECT (j->>'receipt_date')::date FROM policy) scheduled_date,
   c.n,c.receipt_date,c.amount,
   c.n=1 AND c.receipt_date>p.as_of_date received_after_position,
   coalesce((SELECT (j->>'receipt_date')::date FROM policy)<=p_as_of
     AND (SELECT (j->>'receipt_date')::date FROM policy)>p.as_of_date,false) scheduled_after_position
 FROM (SELECT (SELECT value_brl FROM position) value_brl,
   (SELECT as_of_date FROM position) as_of_date,
   (SELECT metadata FROM position) metadata) p CROSS JOIN confirmed c
)
SELECT jsonb_build_object(
 'version','fgts-position-evidence-v386','as_of',p_as_of,
 'status',CASE WHEN value_brl IS NULL THEN 'position_unavailable'
   WHEN received_after_position THEN 'position_after_withdrawal_unavailable'
   WHEN scheduled_after_position THEN 'withdrawal_requires_reconciliation'
   ELSE 'dated_documentary_position' END,
 'balance_brl',CASE WHEN NOT received_after_position AND NOT scheduled_after_position THEN value_brl END,
 'balance_as_of',CASE WHEN value_brl IS NOT NULL AND NOT received_after_position AND NOT scheduled_after_position THEN as_of_date END,
 'last_documented_balance_brl',value_brl,'last_documented_as_of',as_of_date,
 'document_last_posting_date',metadata->'document_last_posting_date',
 'source_label',metadata->'source',
 'withdrawal',jsonb_build_object('confirmed',n=1,'date',CASE WHEN n=1 THEN receipt_date END,'amount_brl',CASE WHEN n=1 THEN amount END),
 'restricted',true,'estimated_contributions_are_documented_balance',false
) FROM state;
$function$;
