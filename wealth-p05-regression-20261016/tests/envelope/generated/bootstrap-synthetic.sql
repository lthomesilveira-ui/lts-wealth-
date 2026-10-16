-- SYNTHETIC ONLY. A brand-new, isolated PostgreSQL17 cluster is required.
DO $roles$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='postgres') THEN CREATE ROLE postgres NOLOGIN; END IF; END $roles$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
GRANT USAGE,CREATE ON SCHEMA public TO postgres;
SET ROLE postgres;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY CHECK(singleton), epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true, 700);
CREATE TABLE public.lts_card_settlement_expense_contract_v273(
 user_id uuid NOT NULL, payment_source_id uuid NOT NULL, active boolean NOT NULL,
 revision text NOT NULL, payload jsonb NOT NULL, PRIMARY KEY(user_id,payment_source_id));
ALTER TABLE public.lts_card_settlement_expense_contract_v273 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_settlement_expense_contract_v273 FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.lts_card_settlement_expense_contract_v273 TO service_role;
INSERT INTO public.lts_card_settlement_expense_contract_v273 VALUES(
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,true,'synthetic-original','{"consumption_manifest":[{"id":"11111111-1111-4111-8111-000000000001","raw_hash":"synthetic-1","signed_amount":-10},{"id":"11111111-1111-4111-8111-000000000002","raw_hash":"synthetic-2","signed_amount":-20},{"id":"11111111-1111-4111-8111-000000000003","raw_hash":"synthetic-3","signed_amount":-30}],"invoice_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","link_contract":{"active":true,"evidence":"SYNTHETIC-EVIDENCE-NOT-A-REAL-DOCUMENT","id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","payment_source_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"},"manifest":[{"id":"11111111-1111-4111-8111-000000000001","raw_hash":"synthetic-1","signed_amount":-10},{"id":"11111111-1111-4111-8111-000000000002","raw_hash":"synthetic-2","signed_amount":-20},{"id":"11111111-1111-4111-8111-000000000003","raw_hash":"synthetic-3","signed_amount":-30}],"synthetic_only":true}'::jsonb);
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid NOT NULL,amount numeric NOT NULL,kind text NOT NULL);
INSERT INTO public.lts_open_finance_staging VALUES
 ('11111111-1111-4111-8111-000000000001'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,10,'expense'),
('11111111-1111-4111-8111-000000000002'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,20,'expense'),
('11111111-1111-4111-8111-000000000003'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,30,'expense'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,60,'payment'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,0,'invoice'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,7,'unrelated');
CREATE TABLE public.lts_card_documentary_payment_link_v272(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,payment_source_id uuid NOT NULL,
 active boolean NOT NULL,evidence text NOT NULL,created_at timestamptz NOT NULL DEFAULT '2001-01-01 00:00:00+00');
INSERT INTO public.lts_card_documentary_payment_link_v272(id,user_id,payment_source_id,active,evidence)
 VALUES('dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,true,
 'SYNTHETIC-EVIDENCE-NOT-A-REAL-DOCUMENT');
CREATE OR REPLACE FUNCTION public.lts_card_settlement_evidence_valid_v273(p_user_id uuid, p_payment_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_items jsonb, p_as_of date, p_contract jsonb, p_coverage jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(

 (p_link-'created_at')=p_contract->'link_contract' AND p_contract->>'active'='true' AND p_contract->>'user_id'=p_user_id::text AND p_contract->>'payment_id'=p_payment_id::text
 AND p_contract->>'invoice_id'=p_link->>'invoice_source_id'
 AND (p_contract->>'amount')::numeric=(p_link->>'expected_amount')::numeric
 AND (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)=p_contract->'manifest'
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i WHERE i#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED' OR i#>>'{raw_payload,status}' IS DISTINCT FROM 'POSTED')
 AND jsonb_typeof(p_coverage)='array'
 AND (SELECT jsonb_agg(jsonb_build_object('id',e->>'source_ref','amount',(e->>'amount')::numeric,'competence_month',e->>'competence_month','coverage_mode',e->>'coverage_mode') ORDER BY e->>'source_ref') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_coverage)='array' THEN p_coverage ELSE '[]'::jsonb END)e)
 = (SELECT jsonb_agg(jsonb_build_object('id',m->>'id','amount',-(m->>'signed_amount')::numeric,'competence_month',p_contract->>'competence_month','coverage_mode',p_contract->>'coverage_mode') ORDER BY m->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_contract->'consumption_manifest')='array' THEN p_contract->'consumption_manifest' ELSE '[]'::jsonb END)m)
 AND
 p_link->>'user_id'=p_user_id::text AND p_invoice->>'user_id'=p_user_id::text AND p_payment->>'user_id'=p_user_id::text
 AND p_link->>'active'='true'
 AND p_link->>'payment_source_id'=p_payment_id::text AND p_payment->>'id'=p_payment_id::text
 AND p_link->>'invoice_source_id'=p_invoice->>'id' AND p_link->>'invoice_source_id'<>p_link->>'payment_source_id'
 AND p_invoice->>'resource_type'='invoice' AND p_payment->>'resource_type'='transaction'
 AND p_invoice->>'provider_deleted_at' IS NULL AND p_payment->>'provider_deleted_at' IS NULL
 AND p_invoice->>'institution_code'=p_link->>'institution_code' AND p_payment->>'institution_code'=p_link->>'institution_code'
 AND split_part(p_invoice->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND split_part(p_payment->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND p_invoice->>'provider_account_ref'=p_link->>'invoice_account_ref'
 AND p_payment->>'provider_account_ref'=p_link->>'payment_account_ref'
 AND p_invoice->>'currency'='BRL' AND p_payment->>'currency'='BRL'
 AND (p_link->>'expected_amount')::numeric>0
 AND (p_invoice->>'signed_amount')::numeric=(p_link->>'expected_amount')::numeric
 AND (p_payment->>'signed_amount')::numeric=-(p_link->>'expected_amount')::numeric
 AND p_invoice#>>'{normalized_payload,due_date}'=p_link->>'expected_due_date'
 AND p_invoice#>>'{normalized_payload,closing_date}'=p_link->>'expected_closing_date'
 AND p_payment->>'posting_date'=p_link->>'expected_payment_date'
 AND (p_link->>'expected_payment_date')::date>(p_link->>'expected_closing_date')::date
 AND (p_link->>'expected_payment_date')::date<=p_as_of
 AND p_payment#>>'{normalized_payload,status}'='POSTED' AND p_payment#>>'{raw_payload,status}'='POSTED'
 AND p_payment#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'
 AND jsonb_array_length(p_contract->'settlement_manifest')=1
 AND (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric AND p_payment->>'raw_hash'=p_link->>'payment_raw_hash'
 AND jsonb_typeof(p_link->'documentary_sources')='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_link->'documentary_sources')='array' THEN p_link->'documentary_sources' ELSE '[]'::jsonb END)>=2
 AND nullif(p_invoice#>>'{normalized_payload,provider_id}','') IS NOT NULL
 AND jsonb_typeof(p_items)='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)>0
 AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i WHERE NOT coalesce(
   i->>'user_id'=p_user_id::text AND i->>'resource_type'='card_transaction' AND i->>'provider_deleted_at' IS NULL
   AND i->>'institution_code'=p_link->>'institution_code' AND i->>'currency'='BRL'
   AND i->>'provider_account_ref'=p_link->>'invoice_account_ref'
   AND i#>>'{raw_payload,creditCardMetadata,billId}'=p_invoice#>>'{normalized_payload,provider_id}'
   AND i->>'signed_amount' IS NOT NULL,false))
 AND (SELECT count(DISTINCT i->>'id')=count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)
 AND (SELECT sum(-(i->>'signed_amount')::numeric) FILTER(WHERE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)=(p_link->>'expected_amount')::numeric
,false)
$function$
;

CREATE FUNCTION public.lts_open_finance_pilot_owner_v1() RETURNS uuid
 LANGUAGE sql IMMUTABLE AS $f$ SELECT 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid; $f$;
CREATE FUNCTION public.lts_expense_effective_rows_v176(p_user uuid,p_start date,p_end date)
 RETURNS TABLE(source_table text,source_ref text,amount numeric,competence_month date,coverage_mode text)
 LANGUAGE sql STABLE AS $f$
 SELECT 'lts_open_finance_staging',id::text,amount,'2026-10-01'::date,'synthetic'
 FROM public.lts_open_finance_staging WHERE user_id=p_user AND kind='expense'; $f$;
CREATE FUNCTION public.lts_expense_effective_rows_pre_v268(p_user uuid,p_start date,p_end date)
 RETURNS TABLE(source_table text,source_ref text,amount numeric,competence_month date,coverage_mode text)
 LANGUAGE sql STABLE AS $f$ SELECT * FROM public.lts_expense_effective_rows_v176(p_user,p_start,p_end); $f$;
CREATE FUNCTION public.lts_card_settlement_expense_excluded_v273(p_user uuid,p_payment uuid,p_coverage jsonb)
 RETURNS boolean LANGUAGE sql STABLE AS $f$
 SELECT coalesce(current_setting('p05_fixture.fail_coverage',true),'off') <> 'on'
 AND jsonb_array_length(p_coverage)=3
 AND EXISTS(SELECT 1 FROM public.lts_card_settlement_expense_contract_v273
 WHERE user_id=p_user AND payment_source_id=p_payment AND revision='synthetic-candidate'); $f$;
CREATE FUNCTION public.lts_v229_expense_rows(p_user uuid,p_start date,p_end date)
 RETURNS TABLE(source_table text,source_ref text,amount numeric)
 LANGUAGE sql STABLE AS $f$
 SELECT 'lts_open_finance_staging',id::text,amount + CASE WHEN kind='unrelated'
 AND current_setting('p05_fixture.fail_unrelated',true)='on'
 AND EXISTS(SELECT 1 FROM public.lts_card_settlement_expense_contract_v273 WHERE revision='synthetic-candidate')
 THEN 1 ELSE 0 END FROM public.lts_open_finance_staging
 WHERE user_id=p_user AND (kind IN('expense','unrelated') OR
 (kind='payment' AND (current_setting('p05_fixture.fail_consumer',true)='on'
 OR EXISTS(SELECT 1 FROM public.lts_card_settlement_expense_contract_v273 WHERE revision='synthetic-original'))))
 UNION ALL SELECT NULL::text,NULL::text,11 + CASE
 WHEN current_setting('p05_fixture.fail_null_unrelated',true)='on'
 AND EXISTS(SELECT 1 FROM public.lts_card_settlement_expense_contract_v273 WHERE revision='synthetic-candidate')
 THEN 1 ELSE 0 END::numeric; $f$;
REVOKE ALL ON FUNCTION public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb) TO postgres,service_role;
REVOKE ALL ON FUNCTION public.lts_open_finance_pilot_owner_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_open_finance_pilot_owner_v1() TO postgres,service_role;
REVOKE ALL ON FUNCTION public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb) TO postgres,service_role;
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) TO postgres,service_role;
REVOKE ALL ON FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date) TO postgres,service_role;
REVOKE ALL ON FUNCTION public.lts_expense_effective_rows_pre_v268(uuid,date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lts_expense_effective_rows_pre_v268(uuid,date,date) TO postgres,service_role;
