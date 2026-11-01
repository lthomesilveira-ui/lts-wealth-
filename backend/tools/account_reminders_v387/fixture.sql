\set ON_ERROR_STOP on
SET TIME ZONE 'America/Sao_Paulo';
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO service_role;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001','owner@example.invalid'),('00000000-0000-4000-8000-000000000002','other@example.invalid');
CREATE SCHEMA lts_cash_alert_private_v377;
GRANT USAGE ON SCHEMA lts_cash_alert_private_v377 TO service_role;
CREATE TABLE public.fixture_financial_events(id integer,amount numeric);
INSERT INTO public.fixture_financial_events VALUES(1,500),(2,-100);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text);
CREATE TABLE public.asset_positions(id uuid,user_id uuid,asset_name text,asset_type text,as_of_date date,created_at timestamptz);
INSERT INTO public.asset_positions VALUES('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','Cofrinho Itaú','cash_investment',current_date-1,now());
CREATE FUNCTION public.lts_open_finance_pilot_owner_v1()RETURNS uuid LANGUAGE sql AS $$SELECT '00000000-0000-4000-8000-000000000001'::uuid$$;
CREATE FUNCTION lts_cash_alert_private_v377.owner_email()RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$SELECT email FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()$$;
REVOKE ALL ON FUNCTION lts_cash_alert_private_v377.owner_email()FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_cash_alert_private_v377.owner_email()TO service_role;
CREATE FUNCTION public.lts_flow_bank_freshness_key_v246(uuid)RETURNS text LANGUAGE sql AS $$SELECT 'synthetic'::text$$;
CREATE FUNCTION public.lts_warm_flow_cache_v245()RETURNS jsonb LANGUAGE sql AS $$SELECT '{"ok":true}'::jsonb$$;
CREATE FUNCTION public.lts_flow_slice_v242(jsonb,date,date)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.lts_flow_card_completeness_v269(jsonb,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_flow_classifications_v290(uuid,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $2$$;
CREATE FUNCTION public.lts_open_finance_current_bank_position_v1(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT '{"bank_cash":60}'::jsonb$$;
CREATE FUNCTION public.lts_confirmed_bank_transfer_schedules_v293(uuid)RETURNS TABLE(source_id uuid,scheduled_date date,from_bank text,to_bank text,signed_amount numeric)LANGUAGE sql AS $$SELECT null::uuid,null::date,null::text,null::text,null::numeric WHERE false$$;
-- Invented balances only; no owner figures, credentials or private documents.
CREATE FUNCTION public.fixture_payload_v387(p_as_of date,p_days integer DEFAULT 30)RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('complete',true,'currency','BRL','flow',jsonb_build_object('current_future',jsonb_build_object('events','[]'::jsonb,'days',
 (SELECT jsonb_agg(jsonb_build_object('date',p_as_of+i,'Itaú',jsonb_build_object('balance',CASE WHEN i<2 THEN 50 WHEN i=2 THEN -20 WHEN i=3 THEN -70 ELSE 100 END),
 'Bradesco',jsonb_build_object('balance',CASE WHEN i<5 THEN 10 ELSE -190 END),'C6',jsonb_build_object('balance',0),
 'fix86_columns',jsonb_build_object('liq_d0_1_recurso',100))ORDER BY i)FROM generate_series(0,p_days-1)i))))
$$;
INSERT INTO public.lts_v229_read_cache SELECT public.lts_open_finance_pilot_owner_v1(),'flow_v242',current_date,current_date,current_date+29,public.fixture_payload_v387(current_date),clock_timestamp(),'v246.1:1:synthetic';
INSERT INTO public.lts_v229_read_cache SELECT '00000000-0000-4000-8000-000000000002','flow_v242',current_date,current_date,current_date+29,'{"other_owner":true}',clock_timestamp(),'v246.1:1:synthetic';
GRANT SELECT ON public.lts_v229_read_cache,public.lts_read_cache_epoch_v242,public.asset_positions TO service_role;
CREATE TABLE public.fixture_assertions_v387(label text PRIMARY KEY);
CREATE FUNCTION public.fixture_assert_v387(p_ok boolean,p_label text)RETURNS void LANGUAGE plpgsql AS $$BEGIN IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'Failed: %',p_label;END IF;INSERT INTO public.fixture_assertions_v387 VALUES(p_label);END$$;
