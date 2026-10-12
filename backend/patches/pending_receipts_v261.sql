-- V261: the review queue uses the same strict receipt proof as realized flow.
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure))<>'f08c8531cc2f3f4723291ef217ab4809' THEN RAISE EXCEPTION 'V261 pending definition changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_pending_projections_v233(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH anchors AS MATERIALIZED (
 SELECT DISTINCT ON (institution) institution bank,(metadata->>'balance_as_of')::date dt
 FROM public.accounts WHERE user_id=p_user_id AND is_active
 AND metadata->>'evidence_sha256' IS NOT NULL AND institution IN ('Itaú','Bradesco','C6')
 AND (metadata->>'balance_as_of')::date<current_date
 ORDER BY institution,(metadata->>'balance_as_of')::date DESC
), candidates AS MATERIALIZED (
 SELECT x||CASE WHEN q.unposted THEN jsonb_build_object('unposted_past_projection',true) ELSE '{}'::jsonb END x
 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date)) x
 JOIN anchors a ON a.bank=x->>'account' AND (x->>'event_date')::date>a.dt
 CROSS JOIN LATERAL(SELECT x->>'source'='current_event' AND (x->>'event_date')::date<current_date
 AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=p_user_id AND fe.is_projection AND NOT fe.is_suppressed
 AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
 AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric) unposted) q
 WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
 AND (x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') OR q.unposted)
), posted AS MATERIALIZED (
 SELECT s.*,CASE institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' ELSE 'C6' END bank
 FROM public.lts_bank_posted_rows_v231(p_user_id) s
 WHERE resource_type='transaction' AND institution_code IN ('341','237','336') AND currency='BRL'
 AND provider_deleted_at IS NULL AND normalized_payload->>'status'='POSTED'
 AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
), positions AS MATERIALIZED (
 SELECT institution_code,normalized_payload->>'provider_account_id' account_id,(normalized_payload->>'as_of')::timestamptz observed_at
 FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND resource_type='balance'
 AND currency='BRL' AND provider_deleted_at IS NULL AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
), payroll AS MATERIALIZED (SELECT projection_ref FROM public.lts_payroll_bank_matches_v231(p_user_id)),
settled_fgts AS MATERIALIZED (
 SELECT receipt->'projection_refs' projection_refs
 FROM posted s JOIN positions p ON p.institution_code=s.institution_code
 AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 CROSS JOIN LATERAL(SELECT public.lts_bank_fgts_combined_receipt_v261(p_user_id,s.id) receipt) proof
 WHERE s.institution_code='341' AND s.signed_amount>0 AND receipt IS NOT NULL
)
SELECT coalesce(jsonb_agg(public.lts_flow_classification_decision_v1(p_user_id,c.x) ORDER BY c.x->>'event_date',c.x->>'source_ref'),'[]'::jsonb)
FROM candidates c WHERE NOT EXISTS(SELECT 1 FROM payroll p WHERE p.projection_ref=c.x->>'source_ref')
AND NOT EXISTS(SELECT 1 FROM settled_fgts s WHERE s.projection_refs ? (c.x->>'source_ref'))
AND NOT EXISTS (
 SELECT 1 FROM posted s JOIN positions p ON p.institution_code=s.institution_code
 AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 WHERE s.bank=c.x->>'account' AND s.posting_date=(c.x->>'event_date')::date
 AND s.signed_amount=(c.x->>'signed_amount')::numeric
 AND (lower(trim(s.description_raw))=lower(trim(c.x->>'description')) OR s.id::text=c.x->>'open_finance_id'
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
 WHERE z->>'ref' IN (c.x->>'source_ref',(c.x->>'source')||':'||(c.x->>'source_ref'))))
)
$function$;
