CREATE OR REPLACE FUNCTION public.lts_realized_bank_sources_v238(p_user_id uuid)
 RETURNS TABLE(financial_event_id uuid, staging_id uuid, bank text, event_date date, signed_amount numeric, description text, legacy_id text, category text, beneficiary text, property_code text, management_group text, management_subgroup text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT f.id,s.id,r.bank,f.event_date,f.amount,f.description_raw,f.legacy_id,r.category,r.beneficiary,r.property_code,r.management_group,r.management_subgroup,r.property_component
FROM public.lts_realized_bank_event_v238 r
JOIN public.financial_events f ON f.id=r.financial_event_id AND f.user_id=r.user_id
JOIN public.lts_open_finance_staging s ON s.id=r.staging_id AND s.user_id=r.user_id
JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
WHERE r.user_id=p_user_id AND NOT f.is_projection AND NOT f.is_suppressed
AND f.event_date=r.expected_date AND f.amount=r.expected_amount
AND s.posting_date=f.event_date AND s.signed_amount=f.amount AND s.currency='BRL'
AND s.resource_type='transaction' AND s.provider_deleted_at IS NULL
AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
AND a.institution=r.bank AND r.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
AND ((f.metadata->>'contract_ref'=r.evidence->>'contract_ref'
AND s.description_raw LIKE '%'||(r.evidence->>'contract_ref')||'%')
OR public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(r),r.evidence))
$function$

