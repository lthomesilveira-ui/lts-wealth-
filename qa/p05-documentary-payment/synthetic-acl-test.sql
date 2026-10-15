BEGIN;
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
SET LOCAL TIME ZONE 'America/Sao_Paulo';
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,institution_code text,provider_record_id text,provider_account_ref text,currency text,signed_amount numeric,normalized_payload jsonb,raw_payload jsonb,posting_date date,raw_hash text);
CREATE TABLE public.lts_card_documentary_payment_link_v272 (
 id uuid PRIMARY KEY,
 user_id uuid NOT NULL,
 invoice_source_id uuid NOT NULL,
 payment_source_id uuid NOT NULL,
 institution_code text NOT NULL,
 provider_item_id text NOT NULL,
 invoice_account_ref text NOT NULL,
 payment_account_ref text NOT NULL,
 expected_amount numeric(18,2) NOT NULL CHECK(expected_amount>0),
 expected_due_date date NOT NULL,
 expected_closing_date date NOT NULL,
 expected_payment_date date NOT NULL,
 invoice_raw_hash text NOT NULL,
 payment_raw_hash text NOT NULL,
 documentary_sources jsonb NOT NULL CHECK(jsonb_typeof(documentary_sources)='array' AND jsonb_array_length(documentary_sources)>=2),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(invoice_source_id<>payment_source_id),
 CHECK(expected_payment_date>expected_closing_date)
);
CREATE UNIQUE INDEX lts_v272_one_invoice_link ON public.lts_card_documentary_payment_link_v272(user_id,invoice_source_id) WHERE active;
CREATE UNIQUE INDEX lts_v272_one_payment_link ON public.lts_card_documentary_payment_link_v272(user_id,payment_source_id) WHERE active;
ALTER TABLE public.lts_card_documentary_payment_link_v272 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_documentary_payment_link_v272 FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.lts_card_documentary_payment_presentation_v272(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH links AS MATERIALIZED (
 SELECT l.id,l.invoice_source_id,l.expected_amount,l.expected_payment_date,l.expected_due_date,
 coalesce(
   b.id IS NOT NULL AND t.id IS NOT NULL
   AND b.resource_type='invoice' AND t.resource_type='transaction'
   AND b.provider_deleted_at IS NULL AND t.provider_deleted_at IS NULL
   AND b.institution_code=l.institution_code AND t.institution_code=l.institution_code
   AND split_part(b.provider_record_id,':',1)=l.provider_item_id
   AND split_part(t.provider_record_id,':',1)=l.provider_item_id
   AND b.provider_account_ref=l.invoice_account_ref
   AND t.provider_account_ref=l.payment_account_ref
   AND b.currency='BRL' AND t.currency='BRL'
   AND b.signed_amount=l.expected_amount AND t.signed_amount=-l.expected_amount
   AND b.normalized_payload->>'due_date'=l.expected_due_date::text
   AND b.normalized_payload->>'closing_date'=l.expected_closing_date::text
   AND t.posting_date=l.expected_payment_date
   AND t.normalized_payload->>'status'='POSTED' AND t.raw_payload->>'status'='POSTED'
   AND l.expected_payment_date<=current_date
   AND b.raw_hash=l.invoice_raw_hash AND t.raw_hash=l.payment_raw_hash,false) valid
 FROM public.lts_card_documentary_payment_link_v272 l
 LEFT JOIN public.lts_open_finance_staging b ON b.id=l.invoice_source_id AND b.user_id=p_user_id
 LEFT JOIN public.lts_open_finance_staging t ON t.id=l.payment_source_id AND t.user_id=p_user_id
 WHERE l.user_id=p_user_id AND l.active
), cards AS (
 SELECT c.ord,CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value||jsonb_build_object('cycles',coalesce((
 SELECT jsonb_agg((y.value-'documentary_payment_evidence')||CASE WHEN l.id IS NULL THEN '{}'::jsonb
 WHEN l.valid AND y.value->>'due_date'=l.expected_due_date::text AND CASE WHEN y.value->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (y.value->>'amount')::numeric=l.expected_amount ELSE false END THEN jsonb_build_object('documentary_payment_evidence',jsonb_build_object(
 'status','identified_in_statement','basis','reviewed_documentary_alias_and_posted_bank_transaction',
 'payment_date',l.expected_payment_date,'amount',l.expected_amount,'currency','BRL','cash_effect','none'))
 ELSE jsonb_build_object('documentary_payment_evidence',jsonb_build_object('status','source_changed','cash_effect','none')) END ORDER BY y.ord)
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value->'cycles' ELSE '[]'::jsonb END) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 ),'[]'::jsonb)) ELSE c.value END value
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN p_payload->'cards' ELSE '[]'::jsonb END) WITH ORDINALITY c(value,ord)
)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN
jsonb_set(p_payload,'{cards}',coalesce((SELECT jsonb_agg(value ORDER BY ord) FROM cards),'[]'::jsonb),false)
ELSE p_payload END
$function$;
REVOKE ALL ON FUNCTION public.lts_card_documentary_payment_presentation_v272(uuid,jsonb) FROM PUBLIC,anon,authenticated;

DO $test$
BEGIN
 IF has_table_privilege('anon','public.lts_card_documentary_payment_link_v272','INSERT') OR has_table_privilege('anon','public.lts_card_documentary_payment_link_v272','UPDATE') OR has_table_privilege('anon','public.lts_card_documentary_payment_link_v272','DELETE') OR has_table_privilege('anon','public.lts_card_documentary_payment_link_v272','SELECT') OR has_table_privilege('authenticated','public.lts_card_documentary_payment_link_v272','SELECT') OR has_table_privilege('authenticated','public.lts_card_documentary_payment_link_v272','INSERT') OR has_table_privilege('authenticated','public.lts_card_documentary_payment_link_v272','UPDATE') OR has_table_privilege('authenticated','public.lts_card_documentary_payment_link_v272','DELETE') THEN RAISE EXCEPTION 'direct table access expanded'; END IF;
 IF has_function_privilege('anon','public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)','EXECUTE') OR has_function_privilege('authenticated','public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'direct helper access expanded'; END IF;
 IF (SELECT relrowsecurity FROM pg_class WHERE oid='public.lts_card_documentary_payment_link_v272'::regclass) IS DISTINCT FROM true THEN RAISE EXCEPTION 'RLS absent'; END IF;
 IF (SELECT prosecdef FROM pg_proc WHERE oid='public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure) IS DISTINCT FROM false THEN RAISE EXCEPTION 'helper unexpectedly security definer'; END IF;
 IF public.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001','{"cards":[]}') IS DISTINCT FROM '{"cards":[]}'::jsonb THEN RAISE EXCEPTION 'empty payload changed'; END IF;
END $test$;
SELECT 'PASS: generic DDL and restricted ACL; disposable database only' result;
ROLLBACK;
