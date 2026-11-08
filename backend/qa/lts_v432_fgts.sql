\set ON_ERROR_STOP on
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,institution_code text,
 currency text,provider_deleted_at timestamptz,normalized_payload jsonb,raw_payload jsonb,
 posting_date date,signed_amount numeric,provider_account_ref text,raw_hash text);
CREATE TABLE public.lts_external_reference_fact(reference_key text,as_of_date date,scope text,value_numeric numeric,
 unit text,confidence text,evidence text,metadata jsonb);
CREATE TABLE public.app_settings(user_id uuid,settings jsonb);
CREATE TABLE public.accounts(id uuid,user_id uuid,institution text,is_active boolean);
CREATE TABLE public.financial_events(user_id uuid,account_id uuid,id uuid,legacy_id text,is_projection boolean,
 is_suppressed boolean,source text,metadata jsonb,event_date date,amount numeric);
CREATE TABLE public.asset_positions(id uuid,user_id uuid,asset_type text,value_brl numeric,as_of_date date,created_at timestamptz,metadata jsonb);
CREATE FUNCTION public.lts_bank_posted_rows_v231(uuid) RETURNS SETOF public.lts_open_finance_staging LANGUAGE sql
 AS $$SELECT * FROM public.lts_open_finance_staging WHERE user_id=$1 AND normalized_payload->>'status'='POSTED'$$;
\ir fixtures/v432/lts_bank_fgts_combined_receipt_v261.sql
\ir fixtures/v432/lts_fgts_position_evidence_v386.sql
REVOKE ALL ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid),public.lts_fgts_position_evidence_v386(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid),public.lts_fgts_position_evidence_v386(uuid,date) TO service_role;
CREATE TABLE attributes_before AS SELECT oid,to_jsonb(p)-'prosrc' attributes FROM pg_proc p WHERE p.oid IN(
 'public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)'::regprocedure,'public.lts_fgts_position_evidence_v386(uuid,date)'::regprocedure);
INSERT INTO public.lts_open_finance_staging VALUES
('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000000','transaction','341','BRL',null,
 '{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}',
 '{"paymentData":{"payer":{"documentNumber":{"type":"CNPJ","value":"00360305000104"},"routingNumber":"104"},"receiver":{"documentNumber":{"type":"CPF","value":"11111111111"}}},"updatedAt":"2000-01-01","order":1}',
 current_date-3,321.09,'synthetic-account','original-hash'),
('00000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000000','balance','341','BRL',null,
 '{"account_type":"CHECKING_ACCOUNT"}','{"taxNumber":"11111111111"}',current_date,0,'synthetic-account','owner-hash');
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-4000-8000-000000000003'::uuid,user_id,resource_type,
 institution_code,currency,provider_deleted_at,normalized_payload,raw_payload,current_date-15,115.23,provider_account_ref,'old-hash'
 FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000001';
INSERT INTO public.app_settings VALUES('10000000-0000-4000-8000-000000000000',
 jsonb_build_object('liquidity_movements_v242',jsonb_build_object('fgts',jsonb_build_object(
 'receipt_date',current_date-15,'total_brl',115.23,'principal_brl',100,'jam_brl',15.23))));
INSERT INTO public.accounts VALUES('30000000-0000-4000-8000-000000000000','10000000-0000-4000-8000-000000000000','Itaú',true);
INSERT INTO public.financial_events VALUES
('10000000-0000-4000-8000-000000000000','30000000-0000-4000-8000-000000000000','40000000-0000-4000-8000-000000000001','principal',true,false,'owner_confirmed_asset_redemption','{"source_asset_type":"FGTS","economic_effect":"asset_reclassification","receipt_component":"principal","receipt_group_id":"synthetic-group"}',current_date-15,100),
('10000000-0000-4000-8000-000000000000','30000000-0000-4000-8000-000000000000','40000000-0000-4000-8000-000000000002','jam',true,false,'owner_confirmed_asset_redemption','{"source_asset_type":"FGTS","economic_effect":"asset_reclassification","receipt_component":"jam","receipt_group_id":"synthetic-group"}',current_date-15,15.23);
INSERT INTO public.asset_positions VALUES('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000000','FGTS',115.23,current_date-20,now(),'{"source":"synthetic-old-statement"}');
CREATE TEMP TABLE source_before AS SELECT * FROM public.lts_open_finance_staging;
CREATE TEMP TABLE old_receipt AS SELECT public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000003')j;
\ir ../patches/v432/owner_confirmed_fgts.sql
\ir ../patches/v432/owner_confirmed_fgts.sql
DO $$BEGIN
 ASSERT public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001') IS NULL;
 ASSERT (SELECT o.j IS NOT NULL AND o.j=public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000003')FROM old_receipt o);
 ASSERT NOT EXISTS(SELECT 1 FROM attributes_before b JOIN pg_proc p ON p.oid=b.oid WHERE b.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc');
 ASSERT NOT has_function_privilege('authenticated','public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)','execute');
 ASSERT NOT has_function_privilege('anon','public.lts_fgts_position_evidence_v386(uuid,date)','execute');
END $$;
INSERT INTO public.lts_external_reference_fact
SELECT 'owner_confirmed_fgts_bank_redemption',posting_date,'synthetic-exact-source',signed_amount,'BRL','user_confirmed','Owner identifies this exact bank receipt as FGTS.',
 jsonb_build_object('user_id',user_id,'staging_id',id,'source_raw_hash',raw_hash,'provider_account_ref',provider_account_ref,
 'asset_type','FGTS','economic_effect','asset_reclassification','owner_confirmed_on',current_date,
 'hash_policy','raw_except_order_updatedAt_v1','source_canonical_sha256',encode(sha256(convert_to((raw_payload-'order'-'updatedAt')::text,'UTF8')),'hex'))
FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000001';
CREATE TEMP TABLE fact_before AS SELECT * FROM public.lts_external_reference_fact;
DO $$DECLARE j jsonb;BEGIN
 j:=public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001');
 ASSERT j->>'total'='321.09' AND j->'projection_refs'='[]'::jsonb;
 ASSERT NOT j?'principal' AND NOT j?'jam','do not invent a principal/interest allocation';
 ASSERT public.lts_bank_fgts_combined_receipt_v261('20000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001')IS NULL;
 j:=public.lts_fgts_position_evidence_v386('10000000-0000-4000-8000-000000000000',current_date);
 ASSERT j->>'balance_brl' IS NULL AND (j#>>'{withdrawal,date}')::date=current_date-3,
  'a confirmed withdrawal does not invent a zero balance without a later position';
END $$;

DO $test$DECLARE mutation text;BEGIN
 FOREACH mutation IN ARRAY ARRAY[
 $m$UPDATE public.lts_external_reference_fact SET confidence='inferred'$m$,
 $m$UPDATE public.lts_external_reference_fact SET value_numeric=321.10$m$,
 $m$UPDATE public.lts_external_reference_fact SET as_of_date=current_date-2$m$,
 $m$UPDATE public.lts_external_reference_fact SET unit='USD'$m$,
 $m$UPDATE public.lts_external_reference_fact SET evidence=' '$m$,
 $m$UPDATE public.lts_external_reference_fact SET metadata=jsonb_set(metadata,'{user_id}','"20000000-0000-4000-8000-000000000000"')$m$,
 $m$UPDATE public.lts_external_reference_fact SET metadata=jsonb_set(metadata,'{owner_confirmed_on}','"invalid-date"')$m$,
 $m$UPDATE public.lts_external_reference_fact SET metadata=jsonb_set(metadata,'{owner_confirmed_on}',to_jsonb((current_date+1)::text))$m$,
 $m$UPDATE public.lts_open_finance_staging SET signed_amount=321.10 WHERE id='00000000-0000-4000-8000-000000000001'$m$,
 $m$UPDATE public.lts_open_finance_staging SET currency='USD' WHERE id='00000000-0000-4000-8000-000000000001'$m$,
 $m$UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000001'$m$,
 $m$UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"')WHERE id='00000000-0000-4000-8000-000000000001'$m$,
 $m$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{paymentData,payer,routingNumber}','"999"')WHERE id='00000000-0000-4000-8000-000000000001'$m$,
 $m$UPDATE public.lts_open_finance_staging SET raw_payload='{"taxNumber":"22222222222"}'WHERE resource_type='balance'$m$,
 $m$UPDATE public.lts_open_finance_staging SET raw_hash='new-hash',raw_payload=raw_payload||'{"meaningful_change":true}'WHERE id='00000000-0000-4000-8000-000000000001'$m$
 ]LOOP
 EXECUTE mutation;
 ASSERT public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001')IS NULL,mutation;
 TRUNCATE public.lts_open_finance_staging;INSERT INTO public.lts_open_finance_staging SELECT * FROM source_before;
 TRUNCATE public.lts_external_reference_fact;INSERT INTO public.lts_external_reference_fact SELECT * FROM fact_before;
 END LOOP;
END $test$;
-- Consultation metadata alone preserves a previously exact owner statement.
UPDATE public.lts_open_finance_staging SET raw_hash='consultation-hash',
 raw_payload=jsonb_set(jsonb_set(raw_payload,'{updatedAt}','"2001-01-01"'),'{order}','99')
WHERE id='00000000-0000-4000-8000-000000000001';
DO $$BEGIN ASSERT public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001')IS NOT NULL;END $$;
INSERT INTO public.lts_external_reference_fact SELECT reference_key,as_of_date,'duplicate',value_numeric,unit,confidence,evidence,metadata FROM fact_before;
DO $$BEGIN ASSERT public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000001')IS NULL;END $$;
DELETE FROM public.lts_external_reference_fact WHERE scope='duplicate';

-- A new owner-confirmed zero is dated: the previous history is preserved.
INSERT INTO public.asset_positions VALUES('50000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000000','FGTS',0,current_date-3,now(),'{"source":"owner confirmed post-withdrawal zero","position_basis":"owner_confirmed"}');
DO $$DECLARE j jsonb;BEGIN
 j:=public.lts_fgts_position_evidence_v386('10000000-0000-4000-8000-000000000000',current_date);
 ASSERT (j->>'balance_brl')::numeric=0 AND (j->>'balance_as_of')::date=current_date-3;
 ASSERT j#>>'{withdrawal,confirmed}'='true' AND (j#>>'{withdrawal,date}')::date=current_date-3;
 ASSERT (j#>>'{withdrawal,amount_brl}')::numeric=321.09;
 j:=public.lts_fgts_position_evidence_v386('10000000-0000-4000-8000-000000000000',current_date-4);
 ASSERT j->>'balance_brl'IS NULL AND (j#>>'{withdrawal,date}')::date=current_date-15;
 ASSERT (SELECT count(*)=2 FROM public.asset_positions);
 ASSERT (SELECT o.j=public.lts_bank_fgts_combined_receipt_v261('10000000-0000-4000-8000-000000000000','00000000-0000-4000-8000-000000000003')FROM old_receipt o);
END $$;
SELECT '{"pass":true,"synthetic_only":true,"scope":"exact owner-confirmed FGTS receipt and dated post-withdrawal zero"}'::jsonb;

