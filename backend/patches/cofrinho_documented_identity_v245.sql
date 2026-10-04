-- Exact documented bank source/hash matching remains mandatory; no amount-only inference.
CREATE OR REPLACE FUNCTION public.lts_documented_bank_event_identity_v240(p_user_id uuid, p_staging_id uuid, p_event jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm
 JOIN public.lts_open_finance_staging s ON s.user_id=dm.user_id AND s.id=dm.staging_id
 JOIN public.financial_events f ON f.user_id=dm.user_id AND (f.id::text=dm.source_ref OR f.legacy_id=dm.source_ref)
 WHERE dm.user_id=p_user_id AND dm.staging_id=p_staging_id AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.signed_amount=dm.signed_amount AND s.posting_date=dm.canonical_date
 AND f.event_date=dm.canonical_date AND f.amount=dm.signed_amount AND NOT f.is_projection AND NOT f.is_suppressed
 AND f.metadata->>'bank_staging_id'=s.id::text AND f.metadata#>>'{bank_reconciliation_evidence,bank_raw_hash}'=s.raw_hash
 AND (p_event->>'source_ref' IN(f.id::text,f.legacy_id)
 OR (p_event->>'source'='liquidity_movement' AND p_event->>'source_ref'='financial_events:'||f.id::text
  AND EXISTS(SELECT 1 FROM public.lts_liquidity_movement m WHERE m.user_id=f.user_id AND m.bank_event_id=f.id AND m.status='active')))
 AND p_event->>'account'=dm.bank AND (p_event->>'event_date')::date=dm.canonical_date
 AND (p_event->>'signed_amount')::numeric=dm.signed_amount)
 OR EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm
 JOIN public.lts_open_finance_staging s ON s.user_id=dm.user_id AND s.id=dm.staging_id
 JOIN public.lts_fact_confirmation f ON f.user_id=dm.user_id AND f.source_ref=dm.source_ref
 WHERE dm.user_id=p_user_id AND dm.staging_id=p_staging_id
 AND f.confirmation_source='documented_open_finance_full_payment'
 AND dm.evidence->>'basis'='official_bill_FULL_PAYMENT_plus_linked_posted_card_credit_and_unique_posted_checking_debit'
 AND dm.evidence->>'bank_source_id'=s.id::text AND dm.evidence->>'bank_raw_hash'=s.raw_hash
 AND s.provider_deleted_at IS NULL AND s.resource_type='transaction' AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.posting_date=dm.canonical_date AND s.signed_amount=dm.signed_amount
 AND f.event_date=dm.canonical_date AND f.account=dm.bank AND f.signed_amount=dm.signed_amount
 AND p_event->>'source_ref'=f.source_ref AND p_event->>'account'=dm.bank
 AND (p_event->>'event_date')::date=dm.canonical_date AND (p_event->>'signed_amount')::numeric=dm.signed_amount)
$function$
;
