CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
CREATE TABLE public.asset_positions (
 id uuid PRIMARY KEY,user_id uuid,asset_type text,asset_name text,as_of_date date,
 value_brl numeric,liquidity_class text,is_available_now boolean,metadata jsonb DEFAULT '{}'
);
CREATE TABLE public.lts_validated_lock_registry (
 lock_key text PRIMARY KEY,canonical_value jsonb,locked_at timestamptz DEFAULT now(),superseded_at timestamptz
);
CREATE TABLE public.lts_open_finance_connection (
 id uuid PRIMARY KEY,user_id uuid,provider text,institution_code text,provider_connection_ref text
);
CREATE TABLE public.lts_open_finance_staging (
 id uuid PRIMARY KEY,user_id uuid,connection_id uuid,provider text,resource_type text,
 institution_code text,currency text,provider_deleted_at timestamptz,posting_date date,
 occurred_at timestamptz,signed_amount numeric,provider_account_ref text,provider_record_id text,
 description_raw text,normalized_payload jsonb,raw_payload jsonb,raw_hash text
);
CREATE TABLE public.lts_liquidity_movement (
 id uuid PRIMARY KEY,user_id uuid,asset_position_id uuid,bank_event_id uuid,event_date date,
 status text,movement_type text,bank_delta_brl numeric,asset_delta_brl numeric,metadata jsonb
);
CREATE TABLE public.financial_events(id uuid PRIMARY KEY,user_id uuid,metadata jsonb);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.qa_checking(user_id uuid,account_ref text);
CREATE FUNCTION public.lts_open_finance_checking_positions_v1(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('bank','Itaú','payload',jsonb_build_object('provider_account_id',account_ref))),'[]')
 FROM public.qa_checking WHERE user_id=p_user_id;
$$;

-- Synthetic identifiers and balances only. These are not user/account fixtures.
INSERT INTO public.qa_checking VALUES('11111111-1111-4111-8111-111111111111','synthetic-account');
INSERT INTO public.lts_open_finance_connection VALUES(
 '33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','pluggy','341','synthetic-item');
INSERT INTO public.asset_positions VALUES(
 '44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2030-01-01',1000,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20300101"}'),(
 '44444444-4444-4444-8444-444444444445','11111111-1111-4111-8111-111111111111','other','Other asset','2030-01-01',500,'restricted',false,'{}');
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value) VALUES(
 'itau_cofrinho_fixture_20300101','{"as_of":"2030-01-01","amount":1000}');

CREATE FUNCTION public.qa_receipt(p_id uuid,p_date date,p_amount numeric)
RETURNS void LANGUAGE sql AS $$
 INSERT INTO public.lts_open_finance_staging VALUES(
 p_id,'11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','pluggy','transaction','341','BRL',NULL,p_date,
 p_date::timestamptz+interval '15 hours',p_amount,'synthetic-account','synthetic-item:'||p_id,
 'Resgate RESGATE COFRINHOS',
 jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','provider_account_id','synthetic-account','item_id','synthetic-item','provider_id',p_id),
 jsonb_build_object('id',p_id,'status','POSTED','accountId','synthetic-account','type','CREDIT','currencyCode','BRL','amount',p_amount,'description','Resgate RESGATE COFRINHOS'),
 md5(p_id::text));
$$;
SELECT public.qa_receipt('55555555-5555-4555-8555-555555555552','2030-01-02',100);
SELECT public.qa_receipt('55555555-5555-4555-8555-555555555553','2030-01-03',200);
INSERT INTO public.lts_liquidity_movement VALUES(
 '66666666-6666-4666-8666-666666666666','11111111-1111-4111-8111-111111111111','44444444-4444-4444-8444-444444444444',NULL,'2030-01-02','active','redemption',100,-100,
 '{"bank_staging_id":"55555555-5555-4555-8555-555555555552"}');
