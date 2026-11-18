\set ON_ERROR_STOP on
BEGIN;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
CREATE TABLE public.lts_open_finance_staging (
 id uuid,user_id uuid,provider text,provider_record_id text,institution_name text,description_raw text,signed_amount numeric,
 resource_type text,currency text,posting_date date,provider_deleted_at timestamptz,normalized_payload jsonb,last_seen_at timestamptz
);
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower($1)';
\ir ../recurring_budgets_v469/functions.sql
\ir functions.sql
\ir test_cases.sql
DO $test$
DECLARE
 u uuid:='00000000-0000-0000-0000-000000000001'; rows jsonb;
 policy jsonb:='{"bank_commitments":[{"id":"water","institution":"Example","merchant_pattern":"water company","starts_on":"2028-04-01"}]}';
BEGIN
 INSERT INTO public.lts_open_finance_staging(user_id,provider,provider_record_id,institution_name,description_raw,signed_amount,resource_type,currency,posting_date,normalized_payload)
 SELECT u,'test',id,bank,merchant,amount,resource,'BRL','2028-04-05',jsonb_build_object('status',status,'account_type',account_type)
 FROM (VALUES ('a','Example','Water Company',-32,'transaction','POSTED','CHECKING_ACCOUNT'),
 ('a','Example','Water Company',-32,'transaction','PENDING','CHECKING_ACCOUNT'),
 ('b','Example','Water Company',-40,'transaction','PENDING','CHECKING_ACCOUNT'),
 ('c','Example','Water Company',-40,'card_transaction','POSTED','CREDIT_CARD'),
 ('d','Other bank','Water Company',-40,'transaction','POSTED','CHECKING_ACCOUNT'),
 ('e','Example','Other company',-40,'transaction','POSTED','CHECKING_ACCOUNT'),
 ('f','Example','Water Company',40,'transaction','POSTED','CHECKING_ACCOUNT')) f(id,bank,merchant,amount,resource,status,account_type);
 rows:=lts_recurring_private_v469.posted_bank_v479(u,'2028-04-10',policy);
 ASSERT jsonb_array_length(rows)=1 AND rows#>>'{0,receipt}'='test:a';
END $test$;
ROLLBACK;
