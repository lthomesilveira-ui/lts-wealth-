\set ON_ERROR_STOP on
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid,resource_type text,currency text,provider_deleted_at timestamptz,
 normalized_payload jsonb,raw_payload jsonb,posting_date date,signed_amount numeric,
 institution_code text,provider_account_ref text,raw_hash text);
CREATE TABLE approved_schedule(
 user_id uuid,source_id uuid,event_date date,from_bank text,to_bank text,signed_amount numeric,
 source_raw_hash text,confirmation_raw_hash text);
CREATE TABLE public.lts_external_reference_fact(reference_key text,confidence text,metadata jsonb);
CREATE FUNCTION public.lts_bank_posted_rows_v231(uuid) RETURNS SETOF public.lts_open_finance_staging LANGUAGE sql
 AS $$SELECT * FROM public.lts_open_finance_staging WHERE user_id=$1 AND normalized_payload->>'status'='POSTED'$$;
CREATE FUNCTION public.lts_previously_proved_transfer_pairs_v363(uuid)
 RETURNS TABLE(debit_id uuid,credit_id uuid) LANGUAGE sql AS $$SELECT null::uuid,null::uuid WHERE false$$;
CREATE FUNCTION public.lts_posted_own_transfer_out_v304(uuid)
 RETURNS TABLE(source_id uuid,event_date date,from_bank text,to_bank text,signed_amount numeric,source_raw_hash text,confirmation_raw_hash text)
 LANGUAGE sql AS $$SELECT source_id,event_date,from_bank,to_bank,signed_amount,source_raw_hash,confirmation_raw_hash FROM public.approved_schedule WHERE user_id=$1$$;
\ir fixtures/v431/lts_owner_confirmed_transfer_pairs_v263.sql
REVOKE ALL ON FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(uuid) TO service_role;
CREATE TABLE attributes_before AS SELECT to_jsonb(p)-'prosrc' attributes FROM pg_proc p
 WHERE p.oid='public.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure;
\ir ../patches/v431/confirmed_schedule_pairs.sql
\ir ../patches/v431/confirmed_schedule_pairs.sql

-- Synthetic identities and values only. A conflicting credit payer CPF is deliberate.
INSERT INTO public.lts_open_finance_staging VALUES
('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000000','transaction','BRL',null,
 '{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}',
 '{"paymentData":{"paymentMethod":"PIX","payer":{"documentNumber":{"type":"CPF","value":"11111111111"}},"receiver":{"routingNumber":"237","documentNumber":{"type":"CPF","value":"11111111111"}}}}',
 current_date,-123.45,'341','origin','debit-hash'),
('00000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000000','transaction','BRL',null,
 '{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}',
 '{"paymentData":{"paymentMethod":"PIX","payer":{"routingNumber":"341","documentNumber":{"type":"CPF","value":"99999999999"}},"receiver":{"documentNumber":{"type":"CPF","value":"11111111111"}}}}',
 current_date,123.45,'237','destination','credit-hash'),
('00000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000000','balance','BRL',null,
 '{"account_type":"CHECKING_ACCOUNT"}','{"taxNumber":"11111111111"}',current_date,null,'341','origin','origin-owner'),
('00000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000000','balance','BRL',null,
 '{"account_type":"CHECKING_ACCOUNT"}','{"taxNumber":"11111111111"}',current_date,null,'237','destination','destination-owner');
CREATE TEMP TABLE source_before AS SELECT * FROM public.lts_open_finance_staging;
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000')),
  'matching date, amount and identity cannot invent a confirmation';
END $$;
INSERT INTO approved_schedule VALUES('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001',
 current_date,'Itaú','Bradesco',-123.45,'debit-hash','reviewed-schedule-hash');
DO $$ BEGIN
 ASSERT (SELECT count(*)=1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000'));
 ASSERT (SELECT count(*)=1 FROM public.lts_owner_confirmed_transfer_pairs_v263('10000000-0000-4000-8000-000000000000'));
 ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('20000000-0000-4000-8000-000000000000'));
 ASSERT NOT has_function_privilege('authenticated','public.lts_confirmed_schedule_pairs_v431(uuid)','execute');
 ASSERT NOT has_function_privilege('anon','public.lts_confirmed_schedule_pairs_v431(uuid)','execute');
 ASSERT has_function_privilege('service_role','public.lts_confirmed_schedule_pairs_v431(uuid)','execute');
 ASSERT (SELECT attributes=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
  WHERE p.oid='public.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure) FROM attributes_before);
END $$;

-- Each changed financial or identity fact must remove the derived pair.
DO $test$ DECLARE mutation text; BEGIN
 FOREACH mutation IN ARRAY ARRAY[
  $m$UPDATE public.lts_open_finance_staging SET signed_amount=123.46 WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET posting_date=current_date-1 WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET currency='USD' WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET raw_hash='changed' WHERE id='00000000-0000-4000-8000-000000000001'$m$,
  $m$UPDATE public.lts_open_finance_staging SET normalized_payload='{"status":"PENDING","account_type":"CHECKING_ACCOUNT"}' WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET normalized_payload='{"status":"POSTED","account_type":"CREDIT_CARD"}' WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{paymentData,payer,routingNumber}','"336"') WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{paymentData,receiver,documentNumber,value}','"22222222222"') WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{paymentData,paymentMethod}','"TED"') WHERE id='00000000-0000-4000-8000-000000000002'$m$,
  $m$UPDATE public.lts_open_finance_staging SET raw_payload='{"taxNumber":"22222222222"}' WHERE id='00000000-0000-4000-8000-000000000004'$m$,
  $m$UPDATE public.lts_open_finance_staging SET provider_account_ref='other' WHERE id='00000000-0000-4000-8000-000000000002'$m$
 ] LOOP
  EXECUTE mutation;
  ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000')),mutation;
  TRUNCATE public.lts_open_finance_staging;
  INSERT INTO public.lts_open_finance_staging SELECT * FROM source_before;
 END LOOP;
END $test$;

-- Two actual credits or two approved debits make the proposed pair ambiguous.
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-4000-8000-000000000005'::uuid,user_id,resource_type,currency,
 provider_deleted_at,normalized_payload,raw_payload,posting_date,signed_amount,institution_code,provider_account_ref,'duplicate-credit'
 FROM source_before WHERE id='00000000-0000-4000-8000-000000000002';
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000'));END $$;
DELETE FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000005';
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-4000-8000-000000000005'::uuid,user_id,resource_type,currency,
 provider_deleted_at,normalized_payload,raw_payload,posting_date,signed_amount,institution_code,provider_account_ref,'duplicate-debit'
 FROM source_before WHERE id='00000000-0000-4000-8000-000000000001';
INSERT INTO approved_schedule SELECT user_id,'00000000-0000-4000-8000-000000000005'::uuid,event_date,from_bank,to_bank,signed_amount,'duplicate-debit',confirmation_raw_hash FROM approved_schedule;
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000'));END $$;
DELETE FROM approved_schedule WHERE source_id='00000000-0000-4000-8000-000000000005';
DELETE FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000005';
UPDATE approved_schedule SET to_bank='C6';
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM public.lts_confirmed_schedule_pairs_v431('10000000-0000-4000-8000-000000000000'));END $$;
UPDATE approved_schedule SET to_bank='Bradesco';

-- The existing explicit-pair path still works without a schedule.
TRUNCATE approved_schedule;
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{paymentData,payer,documentNumber,value}','"11111111111"')
 WHERE id='00000000-0000-4000-8000-000000000002';
INSERT INTO public.lts_external_reference_fact VALUES('owner_confirmed_internal_transfer_pair','user_confirmed',
 '{"user_id":"10000000-0000-4000-8000-000000000000","confirmation_kind":"explicit_exact_pair","debit_id":"00000000-0000-4000-8000-000000000001","credit_id":"00000000-0000-4000-8000-000000000002","debit_raw_hash":"debit-hash","credit_raw_hash":"credit-hash"}');
DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.lts_owner_confirmed_transfer_pairs_v263('10000000-0000-4000-8000-000000000000'));END $$;
SELECT '{"pass":true,"synthetic_only":true,"scope":"previously-confirmed-schedule-to-unique-posted-credit"}'::jsonb;

