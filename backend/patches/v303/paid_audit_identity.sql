-- Read-only identities, from the existing payroll and card-settlement proofs.
-- This does not create a forecast, payment, income or expense.
CREATE OR REPLACE FUNCTION public.lts_recurring_receipt_identities_v303(p_user_id uuid,p_as_of date)
RETURNS TABLE(staging_id uuid,projection_ref text,projection_date date,description text,
 series_key text,direction text,actual_date date,actual_amount numeric,basis text)
LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH payroll AS (
 SELECT m.staging_id,m.projection_ref,m.projection_date,e.dados->>'desc' description,
 public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,'income'::text direction,
 s.posting_date actual_date,s.signed_amount actual_amount,'proved_payroll_projection'::text basis
 FROM public.lts_payroll_bank_matches_v231(p_user_id)m
 JOIN public.evento_base e ON e.usuario_id=p_user_id AND m.projection_ref='evento_base:'||e.idx::text
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=m.staging_id
 WHERE e.dados->>'dia'=m.projection_date::text AND e.dados->>'efeito'='entrada'
 AND m.projection_amount=CASE WHEN e.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$' THEN abs((e.dados->>'valor')::numeric) END
 AND m.actual_amount=m.projection_amount AND m.actual_amount>0 AND s.signed_amount=m.actual_amount
 AND s.posting_date=m.actual_date AND m.projection_date<=p_as_of
 AND s.resource_type='transaction' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND m.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND s.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
 AND public.lts_forecast_series_key_v1(e.dados->>'desc') IN('salary','salary_advance')
), cards AS (
 SELECT pay.id staging_id,'evento_base:'||e.idx::text projection_ref,l.expected_due_date projection_date,
 e.dados->>'desc' description,public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,
 'expense'::text direction,pay.posting_date actual_date,pay.signed_amount actual_amount,
 'proved_legacy_card_settlement'::text basis
 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.evento_base e ON e.usuario_id=l.user_id AND e.dados->>'dia'=l.expected_due_date::text
  AND public.lts_v178_norm(e.dados->>'desc')='mastercard' AND public.lts_v178_norm(e.dados->>'conta')='itau'
  AND e.dados->>'efeito'='saida'
 WHERE l.user_id=p_user_id AND l.active AND inv.institution_code='341' AND pay.institution_code='341'
 AND public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)='itau_mastercard'
 AND pay.resource_type='transaction' AND pay.currency='BRL' AND pay.provider_deleted_at IS NULL AND pay.signed_amount<0
 AND pay.normalized_payload->>'status'='POSTED' AND pay.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND pay.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of AND l.expected_due_date<=p_as_of
 AND public.lts_legacy_mastercard_settled_v291(p_user_id,jsonb_build_object('source','legacy_fix86',
 'source_ref','evento_base:'||e.idx::text,'description',e.dados->>'desc','account','Itaú','event_date',e.dados->>'dia',
 'signed_amount',CASE WHEN e.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$' THEN -abs((e.dados->>'valor')::numeric) END,
 'internal_transfer',false))
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,p_as_of) IS NOT NULL
), candidates AS (SELECT * FROM payroll UNION ALL SELECT * FROM cards), unambiguous AS (
 SELECT staging_id FROM candidates GROUP BY staging_id
 HAVING count(DISTINCT projection_ref)=1 AND count(DISTINCT series_key)=1
 AND count(DISTINCT direction)=1 AND count(DISTINCT actual_amount)=1
)
SELECT DISTINCT c.* FROM candidates c JOIN unambiguous u USING(staging_id);
$fn$;
REVOKE ALL ON FUNCTION public.lts_recurring_receipt_identities_v303(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_recurring_receipt_identities_v303(uuid,date) TO service_role;

DO $patch$
DECLARE d text;anchor text:=$anchor$), bank_actual AS MATERIALIZED (
 SELECT s.id$anchor$;
 join_anchor text:=$join$FROM params p CROSS JOIN LATERAL public.lts_bank_posted_rows_v231(p_user_id) s
 LEFT JOIN LATERAL$join$;
 obligation_anchor text:=$obligation$ AND f.confidence IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
), fixed_specs AS ($obligation$;
BEGIN
 SELECT pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) INTO d;
 IF d LIKE '%receipt_identities_v303%' THEN RETURN;END IF;
 IF strpos(d,anchor)=0 OR strpos(d,join_anchor)=0 OR strpos(d,obligation_anchor)=0
 OR (length(d)-length(replace(d,'coalesce(identity.description','')))/length('coalesce(identity.description')<>2
 THEN RAISE EXCEPTION 'Forecast audit source contract changed';END IF;
 d:=replace(d,anchor,$new$), receipt_identities_v303 AS MATERIALIZED (
 SELECT r.* FROM params p CROSS JOIN LATERAL public.lts_recurring_receipt_identities_v303(p_user_id,p.as_of)r
), bank_actual AS MATERIALIZED (
 SELECT s.id$new$);
 d:=replace(d,join_anchor,$new$FROM params p CROSS JOIN LATERAL public.lts_bank_posted_rows_v231(p_user_id) s
 LEFT JOIN receipt_identities_v303 receipt_v303 ON receipt_v303.staging_id=s.id
  AND receipt_v303.actual_date=s.posting_date AND receipt_v303.actual_amount=s.signed_amount
 LEFT JOIN LATERAL$new$);
 d:=replace(d,'coalesce(identity.description','coalesce(receipt_v303.description,identity.description');
 d:=replace(d,obligation_anchor,$new$ AND f.confidence IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
 AND NOT EXISTS(SELECT 1 FROM receipt_identities_v303 paid WHERE paid.projection_ref=f.source_ref
  AND paid.projection_date=f.event_date AND paid.series_key=f.series_key AND paid.direction=f.direction)
), fixed_specs AS ($new$);
 d:=replace(d,'''version'',''calendar-forecast-coverage-v266''',
 '''version'',''calendar-forecast-coverage-v266'',''receipt_identity_revision'',''v303-proved-bank-receipts''');
 EXECUTE d;
END $patch$;
