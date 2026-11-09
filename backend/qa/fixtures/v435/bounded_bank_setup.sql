CREATE SCHEMA fixture_v435;

CREATE FUNCTION fixture_v435.id(n integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
 SELECT ('ad435000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;

CREATE TABLE public.lts_open_finance_staging (
 id uuid PRIMARY KEY,user_id uuid NOT NULL,resource_type text,posting_date date,signed_amount numeric,
 currency text,normalized_payload jsonb,raw_payload jsonb,institution_code text,provider_account_ref text,
 description_raw text,first_seen_at timestamptz DEFAULT now(),provider_deleted_at timestamptz
);
CREATE TABLE public.accounts (user_id uuid,institution text,is_active boolean,metadata jsonb);
CREATE TABLE public.lts_semantic_rule (user_id uuid,active boolean,confidence text,is_internal_transfer boolean,
 is_asset_movement boolean,match_type text,match_value text,category text);
CREATE TABLE public.lts_v229_documentary_match (user_id uuid,staging_id uuid);
CREATE SEQUENCE fixture_v435.context_calls;

CREATE FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(p_user uuid)
RETURNS TABLE(debit_id uuid,credit_id uuid) LANGUAGE sql STABLE AS $$
 SELECT fixture_v435.id(104),fixture_v435.id(114) WHERE p_user=fixture_v435.id(1)
$$;
CREATE FUNCTION public.lts_posted_own_transfer_out_v304(p_user uuid)
RETURNS TABLE(source_id uuid) LANGUAGE sql STABLE AS $$
 SELECT fixture_v435.id(105) WHERE p_user=fixture_v435.id(1)
$$;
CREATE FUNCTION public.lts_flow_operational_read_v229(p_user uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 PERFORM nextval('fixture_v435.context_calls');
 IF p_user=fixture_v435.id(1) THEN
  IF p_from IS DISTINCT FROM date '2026-02-01' OR p_to IS DISTINCT FROM current_date THEN
   RAISE EXCEPTION 'Unexpected context window';
  END IF;
  RETURN jsonb_build_array(
   jsonb_build_object('account','Itaú','event_date','2026-02-10','signed_amount',-46,
    'open_finance_id',fixture_v435.id(106),'description','Different bank caption'),
   jsonb_build_object('account','Itaú','event_date','2026-02-10','signed_amount',-66,
    'source','fixture','source_ref','case:116','description','Matched via reference')
  );
 END IF;
 RETURN '[]'::jsonb;
END $$;
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower(trim($1))';
CREATE FUNCTION public.lts_bank_description_key_v229(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower(trim($1))';
CREATE FUNCTION public.lts_bank_known_classification_v231(p_user uuid,p_id uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT CASE WHEN p_user=fixture_v435.id(1) AND p_id=fixture_v435.id(108) THEN '{"category":"Known"}'::jsonb END
$$;

INSERT INTO public.accounts VALUES
 (fixture_v435.id(1),'Itaú',true,'{"evidence_sha256":"fixture","balance_as_of":"2026-02-03"}'),
 (fixture_v435.id(1),'Bradesco',true,'{"evidence_sha256":"fixture","balance_as_of":"2026-02-02"}'),
 (fixture_v435.id(1),'Other',true,'{"evidence_sha256":"fixture","balance_as_of":"2026-01-31"}'),
 (fixture_v435.id(2),'Itaú',true,'{"evidence_sha256":"fixture","balance_as_of":"2026-02-01"}');

INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,currency,normalized_payload,raw_payload,
 institution_code,provider_account_ref)
VALUES
 (fixture_v435.id(11),fixture_v435.id(1),'balance','BRL','{"account_type":"CHECKING_ACCOUNT"}','{"taxNumber":"00000000000"}','341','first-a'),
 (fixture_v435.id(12),fixture_v435.id(1),'balance','BRL','{"account_type":"CHECKING_ACCOUNT"}','{"taxNumber":"00000000000"}','237','first-b');

INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,currency,normalized_payload,
 raw_payload,institution_code,provider_account_ref,description_raw)
SELECT fixture_v435.id(n),fixture_v435.id(owner),'transaction',d,amount,'BRL',
 jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','operation_type',operation,
  'reconciliation',CASE WHEN n=116 THEN '{"candidates":[{"ref":"case:116"}]}'::jsonb END),
 CASE WHEN routing IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('paymentData',jsonb_build_object(
  'payer',jsonb_build_object('routingNumber',CASE WHEN amount<0 THEN bank ELSE routing END,'documentNumber',jsonb_build_object('type','CPF','value','00000000000')),
  'receiver',jsonb_build_object('routingNumber',CASE WHEN amount<0 THEN routing ELSE bank END,'documentNumber',jsonb_build_object('type','CPF','value','00000000000')))) END,
 bank,CASE WHEN owner=2 THEN 'second-a' WHEN bank='341' THEN 'first-a' ELSE 'first-b' END,description
FROM (VALUES
 (101,1,date '2026-02-10',-41,'341','237','PIX','Owned debit'),
 (102,1,date '2026-02-10',41,'237','341','PIX','Owned credit'),
 (103,1,date '2026-02-09',41,'237','341','PIX','Other day'),
 (104,1,date '2026-02-10',-44,'341',NULL,'PIX','Confirmed pair'),
 (105,1,date '2026-02-10',-45,'341',NULL,'PIX','Confirmed outbound'),
 (106,1,date '2026-02-10',-46,'341',NULL,'PIX','Present in cash flow'),
 (107,1,date '2026-02-10',-47,'341',NULL,'PIX','Documentary match'),
 (108,1,date '2026-02-10',-48,'341',NULL,'PIX','Known expense'),
 (109,1,date '2026-02-10',-49,'341','237','PIX','Ambiguous debit'),
 (110,1,date '2026-02-10',49,'237','341','PIX','Candidate A'),
 (111,1,date '2026-02-10',49,'237','341','PIX','Candidate B'),
 (114,1,date '2026-02-11',44,'237',NULL,'PIX','Confirmed pair credit'),
 (116,1,date '2026-02-10',-66,'341',NULL,'PIX','Matched ref'),
 (120,1,date '2026-02-04',-61,'341',NULL,'CARTAO','Debit - DOCTO: 1234'),
 (121,1,date '2026-02-11',-61,'341',NULL,'CARTAO','Debit - DOCTO: 1234'),
 (130,1,date '2026-02-03',-72,'341',NULL,'PIX','On anchor'),
 (140,1,current_date+1,-73,'341',NULL,'PIX','Future'),
 (150,2,date '2026-02-10',-75,'341',NULL,'PIX','Other owner')
) t(n,owner,d,amount,bank,routing,operation,description);

INSERT INTO public.lts_semantic_rule VALUES
 (fixture_v435.id(1),true,'high',false,false,'exact','Ambiguous debit','Review');
INSERT INTO public.lts_v229_documentary_match VALUES (fixture_v435.id(1),fixture_v435.id(107));

\ir lts_bank_posted_rows_v231.sql
\ir lts_v229_new_bank_rows.sql
