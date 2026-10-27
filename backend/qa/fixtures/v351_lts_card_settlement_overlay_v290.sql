CREATE OR REPLACE FUNCTION public.lts_card_settlement_overlay_v290(p_user_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH links AS MATERIALIZED(
 SELECT l.invoice_source_id,l.expected_amount,l.expected_due_date,l.expected_payment_date,
 public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) receipt
 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 WHERE l.user_id=p_user_id AND l.active)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN jsonb_set(p_payload,'{cards}',(
 SELECT jsonb_agg(c.value||jsonb_build_object('cycles',(
 SELECT coalesce(jsonb_agg(y.value||CASE WHEN l.receipt IS NOT NULL
 AND (y.value->>'amount')::numeric=l.expected_amount AND (y.value->>'due_date')::date=l.expected_due_date THEN
 jsonb_build_object('source_payment_status',y.value->>'payment_status','payment_status','paid',
 'settlement_confirmed',true,'settled_on',l.expected_payment_date,
 'settlement_basis','reviewed_issuer_full_payment_and_exact_posted_checking_debit')
 ELSE '{}'::jsonb END ORDER BY y.ord),'[]')
 FROM jsonb_array_elements(coalesce(c.value->'cycles','[]')) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 )) ORDER BY c.ord)
 FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
),false) ELSE p_payload END
$function$

