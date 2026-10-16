\set ON_ERROR_STOP on
-- EXCLUSIVELY for a disposable local database. All identifiers and amounts are invented.
DO $$ BEGIN
 IF current_database()<>'wealth_cash_timestamp_synthetic' THEN RAISE EXCEPTION 'synthetic database required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='wealth_test') THEN RAISE EXCEPTION 'fresh disposable database required'; END IF;
END $$;
CREATE SCHEMA wealth_test;
CREATE ROLE wealth_fixture_owner NOLOGIN;
CREATE ROLE wealth_fixture_browser NOLOGIN;
CREATE ROLE wealth_fixture_outsider NOLOGIN;
CREATE TABLE wealth_test.assertions(name text PRIMARY KEY);
CREATE FUNCTION wealth_test.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'assertion failed: %',label; END IF;
INSERT INTO wealth_test.assertions VALUES(label); END $$;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql STABLE SET search_path='' AS $$
BEGIN
 IF nullif(current_setting('wealth_test.user_id',true),'') IS NULL THEN RAISE EXCEPTION 'fixture unauthenticated' USING ERRCODE='42501'; END IF;
 RETURN current_setting('wealth_test.user_id')::uuid;
END $$;
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,resource_type text,institution_code text,currency text,provider_account_ref text,
 signed_amount numeric,provider_deleted_at timestamptz,normalized_payload jsonb,raw_payload jsonb,raw_hash text
);
CREATE TABLE public.lts_validated_lock_registry(lock_key text,canonical_value jsonb,superseded_at timestamptz);
CREATE TABLE public.asset_positions(user_id uuid,asset_type text,value_brl numeric,as_of_date date);
CREATE TABLE wealth_test.resources(user_id uuid PRIMARY KEY,d0 numeric,withdrawals numeric,fgts numeric);
CREATE FUNCTION public.lts_cofrinho_effective_locked_v245(u uuid,d date) RETURNS numeric LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT d0 FROM wealth_test.resources WHERE user_id=u
$$;
CREATE FUNCTION public.lts_liquidity_adjustments_v242(u uuid,d date) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT jsonb_build_object('brokerage_settled_withdrawals',withdrawals,'fgts_documented',fgts) FROM wealth_test.resources WHERE user_id=u
$$;
SELECT set_config('wealth_test.user_id','10000000-0000-0000-0000-000000000001',false);
CREATE FUNCTION wealth_test.reset_fixtures() RETURNS void LANGUAGE plpgsql AS $$
DECLARE b record;
BEGIN
 TRUNCATE public.lts_open_finance_staging,public.lts_validated_lock_registry,public.asset_positions,wealth_test.resources;
 FOR b IN SELECT * FROM (VALUES
 ('00000000-0000-0000-0000-000000000011'::uuid,'341','fixture-itau',1234.56::numeric,'2031-02-13T09:13:11.456Z'),
 ('00000000-0000-0000-0000-000000000012'::uuid,'237','fixture-bradesco',-13.21::numeric,'2031-02-14T06:00:00Z'),
 ('00000000-0000-0000-0000-000000000013'::uuid,'336','fixture-c6',0::numeric,'2031-02-13T02:59:59.999Z')
 ) v(id,bank,account,amount,source_time) LOOP
  INSERT INTO public.lts_open_finance_staging VALUES(b.id,'10000000-0000-0000-0000-000000000001','balance',b.bank,'BRL',b.account,b.amount,NULL,
   jsonb_build_object('balance_semantics','available_bank_balance','available_balance',b.amount,'currency','BRL','account_type','CHECKING_ACCOUNT','provider_account_id',b.account,'as_of',b.source_time,
    'sensitive_unused_fixture','must_not_escape'),
   jsonb_build_object('id',b.account,'balance',b.amount,'currencyCode','BRL','subtype','CHECKING_ACCOUNT','updatedAt',b.source_time),repeat('a',64));
 END LOOP;
 INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-0000-0000-000000000014','10000000-0000-0000-0000-000000000001','transaction','341','BRL','fixture-itau',-12.34,NULL,
  '{"status":"PENDING","official_effect":false}', '{"status":"PENDING"}',repeat('b',64));
 INSERT INTO public.lts_validated_lock_registry VALUES
 ('itau_cofrinho_20260926',jsonb_build_object('amount',12.34,'as_of',current_date-2),NULL),
 ('morgan_available_synthetic',jsonb_build_object('total_available_brl',78.90,'as_of',current_date-1),NULL);
 INSERT INTO public.asset_positions VALUES('10000000-0000-0000-0000-000000000001','FGTS',45.67,current_date-3);
 INSERT INTO wealth_test.resources VALUES('10000000-0000-0000-0000-000000000001',12.34,8.90,44.44);
END $$;
SELECT wealth_test.reset_fixtures();
GRANT USAGE ON SCHEMA public,wealth_test TO wealth_fixture_owner,wealth_fixture_browser,wealth_fixture_outsider;
GRANT SELECT ON ALL TABLES IN SCHEMA public,wealth_test TO wealth_fixture_owner;
