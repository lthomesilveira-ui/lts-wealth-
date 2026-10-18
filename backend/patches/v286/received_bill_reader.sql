-- Caller must run this patch after bill_source_fields.sql in one transaction.
DO $patch$
DECLARE before_identity jsonb;
BEGIN
 IF md5(pg_get_functiondef('public.lts_current_received_card_bills_v263(uuid)'::regprocedure))<>'aae890a623fdd870b2c1973f1891a84f'
 THEN RAISE EXCEPTION 'Received-bill reader changed since reviewed baseline';END IF;
 SELECT to_jsonb(p)-ARRAY['prosrc','probin'] INTO before_identity FROM pg_proc p WHERE oid='public.lts_current_received_card_bills_v263(uuid)'::regprocedure;
 EXECUTE $reader_definition$CREATE OR REPLACE FUNCTION public.lts_current_received_card_bills_v263(p_user_id uuid)
 RETURNS TABLE(family text, card_name text, last4 text, reference_month date, due_date date, amount numeric, source_updated_at timestamp with time zone, received_at timestamp with time zone, invoice_source_id uuid, payment_status text, reported_payment_amount numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH received AS MATERIALIZED (
 SELECT s.id invoice_source_id,s.provider_record_id,s.provider_account_ref,s.raw_payload,
 v.closing_date,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.normalized_payload->>'card_name' card_name,s.normalized_payload->>'last4' last4,
 v.due_date,s.signed_amount amount,s.last_seen_at received_at,
 v.source_updated_at,v.payments_valid
 FROM public.lts_open_finance_staging s
 CROSS JOIN LATERAL public.lts_bill_source_fields_v286(s.normalized_payload,s.raw_payload,s.posting_date) v
 WHERE s.user_id=p_user_id AND s.resource_type='invoice' AND s.provider_deleted_at IS NULL
 AND s.currency='BRL' AND s.signed_amount>=0
 AND s.signed_amount::text ~ '^[0-9]+([.][0-9]+)?$'
 AND v.header_valid
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging a
  WHERE a.user_id=s.user_id AND a.resource_type='credit_card' AND a.provider_deleted_at IS NULL
  AND a.institution_code=s.institution_code
  AND a.normalized_payload->>'provider_account_id'=s.provider_account_ref
  AND public.lts_card_family_v226(a.normalized_payload->>'name',a.institution_name)
   =public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name))
), eligible AS MATERIALIZED (
 SELECT r.*,date_trunc('month',r.due_date)::date reference_month,
 count(*) OVER(PARTITION BY r.family,date_trunc('month',r.due_date)::date) cycle_candidates
 FROM received r WHERE r.due_date>=date_trunc('month',(SELECT min(created_at) FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND resource_type='card_transaction'))::date AND r.source_updated_at IS NOT NULL
), evidence AS MATERIALIZED (
 -- Pluggy payments on Bill N+1 settle Bill N. Never compare Bill N's
 -- own payments with Bill N's amount. Bound dates by the actual close
 -- dates and require a unique adjacent cycle on the same owned account.
 SELECT e.*,coalesce(pay.amount,0) reported_payment_amount,
 n.invoice_source_id next_invoice_source_id,charges.amount charge_amount,
 (coalesce(pay.valid,false) AND coalesce(n.payments_valid,false)) payment_evidence_valid,coalesce(charges.valid,false) charge_evidence_valid
 FROM eligible e LEFT JOIN eligible n ON n.family=e.family
 AND n.provider_account_ref=e.provider_account_ref AND n.cycle_candidates=1
 AND n.reference_month=(e.reference_month+interval '1 month')::date
 AND n.closing_date>e.closing_date
 LEFT JOIN LATERAL (
 SELECT sum(q.amount) amount,bool_and(coalesce(q.valid,false)) valid
 FROM (
  SELECT CASE WHEN count(DISTINCT p::text)=1
   AND min(p->>'currencyCode')='BRL'
   AND min(p->>'valueType') IN('FULL_PAYMENT','PARTIAL_PAYMENT','MINIMUM_PAYMENT','OTHER','OTHER_PAYMENT')
   AND min(p->>'amount') ~ '^[0-9]+([.][0-9]+)?$'
   THEN (min(p->>'amount'))::numeric END amount,
   count(DISTINCT p::text)=1 AND min(p->>'currencyCode')='BRL'
   AND min(p->>'valueType') IN('FULL_PAYMENT','PARTIAL_PAYMENT','MINIMUM_PAYMENT','OTHER','OTHER_PAYMENT')
   AND min(p->>'amount') ~ '^[0-9]+([.][0-9]+)?$' valid
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(n.raw_payload->'payments')='array'
   THEN n.raw_payload->'payments' ELSE '[]'::jsonb END) p
  WHERE nullif(p->>'id','') IS NOT NULL
  AND p->>'paymentDate' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
  AND CASE WHEN pg_catalog.pg_input_is_valid(left(p->>'paymentDate',10),'date') THEN left(p->>'paymentDate',10)::date>e.closing_date ELSE false END
  AND CASE WHEN pg_catalog.pg_input_is_valid(left(p->>'paymentDate',10),'date') THEN left(p->>'paymentDate',10)::date<=least(n.closing_date,current_date) ELSE false END
  GROUP BY p->>'id'
 )q
 )pay ON true
 LEFT JOIN LATERAL (
 SELECT coalesce(sum(CASE WHEN c->>'currencyCode'='BRL'
  AND c->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (c->>'amount')::numeric END),0) amount,
  jsonb_typeof(n.raw_payload->'financeCharges')='array'
  AND count(*)=count(DISTINCT c->>'id')
  AND coalesce(bool_and(coalesce(c->>'currencyCode'='BRL'
  AND c->>'amount' ~ '^[0-9]+([.][0-9]+)?$',false)),true) valid
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(n.raw_payload->'financeCharges')='array'
 THEN n.raw_payload->'financeCharges' ELSE '[]'::jsonb END)c
 )charges ON true
 WHERE e.cycle_candidates=1
)
SELECT e.family,e.card_name,e.last4,e.reference_month,e.due_date,e.amount,
 e.source_updated_at,e.received_at,e.invoice_source_id,
 CASE WHEN e.amount>0 AND e.next_invoice_source_id IS NOT NULL
 AND e.payment_evidence_valid AND e.charge_evidence_valid
 AND abs(e.reported_payment_amount-(e.amount+e.charge_amount))<0.005 THEN 'paid'
 WHEN e.reported_payment_amount>0 THEN 'payment_reported'
 ELSE 'payment_not_reported' END payment_status,e.reported_payment_amount
FROM evidence e
$function$
$reader_definition$;
 IF before_identity IS DISTINCT FROM(SELECT to_jsonb(p)-ARRAY['prosrc','probin'] FROM pg_proc p WHERE oid='public.lts_current_received_card_bills_v263(uuid)'::regprocedure)
 THEN RAISE EXCEPTION 'Received-bill function identity/ACL/configuration changed';END IF;
END $patch$;
