-- Isolated PostgreSQL17 fixture. Every identity and amount is synthetic.
CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE public.asset_positions(id uuid PRIMARY KEY,user_id uuid,legacy_id text,asset_type text,asset_name text,as_of_date date,quantity numeric,unit_price numeric,value_brl numeric,liquidity_class text,availability_note text,metadata jsonb,created_at timestamptz DEFAULT now());
CREATE TABLE public.app_settings(user_id uuid PRIMARY KEY,settings jsonb);
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,institution_code text,currency text,provider_deleted_at timestamptz,posting_date date,signed_amount numeric,normalized_payload jsonb,confirmed boolean);
CREATE TABLE public.lts_future_liquidity_effective_v290(user_id uuid,asset_type text,active boolean,gross_value_brl numeric,net_value_brl numeric);
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE sql AS $$SELECT current_setting('lts.fixture_owner')::uuid$$;
CREATE FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT CASE WHEN confirmed AND normalized_payload->>'status'='POSTED' THEN '{"basis":"synthetic_canonical_matcher"}'::jsonb END FROM public.lts_open_finance_staging WHERE user_id=$1 AND id=$2$$;
CREATE FUNCTION public.lts_browser_wealth_detail_v2() RETURNS jsonb LANGUAGE sql AS $$SELECT '{"wealth":{"summary":{"assets_central":4500,"net_worth_central":null}},"unchanged_finance":{"cash":700,"debt":900,"future":580},"schiavalli":{"status":"old_cached_placeholder"}}'::jsonb$$;
CREATE FUNCTION public.lts_commitments_summary_v1(uuid,date) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"commitments":[{"id":"cipo_396","current_documentary_debt_balance":900,"current_debt_as_of":"2030-01-01"},{"id":"volvo","remaining_scheduled_outflow":580},{"id":"coopharma","remaining_economic_outflow":270},{"id":"pai_mae","remaining_scheduled_outflow":50}]}'::jsonb$$;
CREATE FUNCTION public.lts_documentary_commitments_v1(uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"items":[]}'::jsonb$$;
INSERT INTO public.asset_positions VALUES('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','fgts-one','FGTS','Synthetic FGTS','2030-01-01',NULL,NULL,5010,'restricted','restricted','{"source":"Synthetic statement","document_last_posting_date":"2029-12-21"}',now());
INSERT INTO public.asset_positions VALUES('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000002','fgts-two','FGTS','Other owner FGTS','2030-01-01',NULL,NULL,999,'restricted','restricted','{}',now());
INSERT INTO public.app_settings VALUES('00000000-0000-4000-8000-000000000001','{"liquidity_movements_v242":{"fgts":{"receipt_date":"2030-01-08","total_brl":5010}}}');
INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000001','transaction','341','BRL',NULL,'2030-01-08',5010,'{"status":"POSTED"}',true);
ALTER TABLE public.asset_positions ADD COLUMN is_available_now boolean DEFAULT false;
