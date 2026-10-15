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

INSERT INTO public.lts_open_finance_staging VALUES
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','invoice',NULL,'999','synthetic-item:invoice','synthetic-card','BRL',100,jsonb_build_object('due_date',(current_date-2)::text,'closing_date',(current_date-10)::text),'{}',current_date-2,'invoice-hash'),
('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','transaction',NULL,'999','synthetic-item:payment','synthetic-bank','BRL',-100,'{"status":"POSTED"}','{"status":"POSTED"}',current_date-1,'payment-hash');
INSERT INTO public.lts_card_documentary_payment_link_v272 VALUES
('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','999','synthetic-item','synthetic-card','synthetic-bank',100,current_date-2,current_date-10,current_date-1,'invoice-hash','payment-hash','[{"source":"synthetic-document-1"},{"source":"synthetic-document-2"}]',true,now());
CREATE TABLE public.payload(data jsonb);
INSERT INTO payload VALUES ('{"complete":true,"cards":[{"family":"synthetic-a","cycles":[{"invoice_source_id":"00000000-0000-4000-8000-000000000002","amount":100,"payment_status":"payment_not_reported","due_date":"2030-01-12"}]},{"family":"synthetic-b","cycles":[{"amount":55,"payment_status":"paid"}]}]}');
UPDATE public.payload SET data=jsonb_set(data,'{cards,0,cycles,0,due_date}',to_jsonb((current_date-2)::text));

ALTER TABLE public.lts_open_finance_staging ADD COLUMN institution_name text;
ALTER TABLE public.lts_open_finance_staging ADD COLUMN last_seen_at timestamptz;
CREATE TABLE public.lts_card_document_supplement_v234(user_id uuid,family text,reference_month date,source_as_of date,source_file_ref text);
CREATE TABLE public.lts_v229_card_recurring_commitment(user_id uuid,active boolean,family text,amount numeric,description text,category text);
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql STABLE AS $$ BEGIN IF nullif(current_setting('synthetic.owner',true),'') IS NULL THEN RAISE EXCEPTION 'synthetic unauthenticated'; END IF; RETURN current_setting('synthetic.owner')::uuid; END $$;
CREATE FUNCTION public.lts_card_read_start_v269(uuid) RETURNS text LANGUAGE sql STABLE AS $$ SELECT 'synthetic-revision'::text $$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT $3 $$;
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
CREATE FUNCTION public.lts_browser_card_cycles_v226() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT data FROM public.payload $$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v229()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; cards jsonb;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_card_cycles_v226();
 WITH source_dates AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 max(coalesce(nullif(s.normalized_payload->>'as_of',''),nullif(s.normalized_payload->>'provider_updated_at',''),nullif(s.raw_payload->>'updatedAt',''))::timestamptz) source_updated_at,
 max(s.last_seen_at) received_at
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL GROUP BY 1
 ) SELECT jsonb_agg(c||jsonb_build_object('source_updated_at',sd.source_updated_at,'received_at',sd.received_at,'source_time_basis','provider_resource_update')||jsonb_build_object('document_source_as_of',doc.as_of,'document_source_file',doc.source_file,'documented_supplement_items',doc.n)||CASE WHEN hint.amount IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(c->'cycles','[]'::jsonb)) q
 WHERE q->>'month'=((date_trunc('month',current_date)+interval '1 month')::date)::text) THEN jsonb_build_object(
 'cycles',coalesce(c->'cycles','[]'::jsonb)||jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',
 CASE WHEN c->>'last_due' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
 make_date(extract(year FROM current_date+interval '1 month')::int,extract(month FROM current_date+interval '1 month')::int,
 least(extract(day FROM (c->>'last_due')::date)::int,extract(day FROM date_trunc('month',current_date)+interval '2 months -1 day')::int)) END,
 'due_date_basis','estimate_from_received_due_day',
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN source_dates sd ON sd.family=c->>'family'
 LEFT JOIN LATERAL(SELECT max(d.source_as_of) as_of,min(d.source_file_ref) source_file,count(*) n
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.family=c->>'family'
 AND d.reference_month=date_trunc('month',current_date)::date) doc ON true
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_card_documentary_payment_presentation_v272(u,j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true)));
END $function$;

DO $hash$ BEGIN
 IF md5(pg_get_functiondef('public.lts_browser_card_cycles_v229()'::regprocedure)) IS DISTINCT FROM '68a6ba83a6e4024dc78a38d388038711' THEN RAISE EXCEPTION 'canonical wrapper hash mismatch'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure) IS DISTINCT FROM '2551764656fdc21cfaed325b74c606f0' THEN RAISE EXCEPTION 'helper body hash mismatch'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure AND NOT prosecdef AND cardinality(proconfig)=2 AND proconfig @> ARRAY['search_path=""','TimeZone=America/Sao_Paulo']) THEN RAISE EXCEPTION 'helper configuration mismatch'; END IF;
END $hash$;
REVOKE ALL ON public.payload FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.lts_open_finance_staging FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_card_cycles_v229() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_cycles_v229() TO authenticated;
SET LOCAL ROLE authenticated;
SET LOCAL synthetic.owner='00000000-0000-4000-8000-000000000001';
DO $test$
DECLARE r jsonb;
BEGIN
 r:=public.lts_browser_card_cycles_v229();
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'identified_in_statement' THEN RAISE EXCEPTION 'authenticated owner wrapper failed'; END IF;
 IF r#>>'{cards,0,cycles,0,payment_status}' IS DISTINCT FROM 'payment_not_reported' THEN RAISE EXCEPTION 'provider status changed'; END IF;
END $test$;
SET LOCAL synthetic.owner='00000000-0000-4000-8000-000000000099';
DO $test$
DECLARE r jsonb;
BEGIN
 r:=public.lts_browser_card_cycles_v229();
 IF r#>'{cards,0,cycles,0,documentary_payment_evidence}' IS NOT NULL THEN RAISE EXCEPTION 'cross-owner documentary annotation leak'; END IF;
END $test$;
RESET ROLE;
UPDATE public.lts_open_finance_staging SET raw_hash='changed-after-cached-payload' WHERE resource_type='transaction';
SET LOCAL ROLE authenticated;
SET LOCAL synthetic.owner='00000000-0000-4000-8000-000000000001';
DO $test$
DECLARE r jsonb;
BEGIN
 r:=public.lts_browser_card_cycles_v229();
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'cached payload kept outdated association'; END IF;
END $test$;
SET LOCAL synthetic.owner='';
DO $test$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN PERFORM public.lts_browser_card_cycles_v229(); EXCEPTION WHEN raise_exception THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'unauthenticated wrapper accepted'; END IF;
END $test$;
RESET ROLE;
SELECT 'PASS: exact browser wrapper; synthetic auth/core/revision dependencies; two owners' result;
ROLLBACK;
