CREATE SCHEMA IF NOT EXISTS lts_projection_private_v412;
CREATE TABLE public.fixture_invalidation_v443(user_id uuid);
CREATE FUNCTION lts_projection_private_v412.invalidate_reads(uuid) RETURNS void LANGUAGE sql AS $$INSERT INTO public.fixture_invalidation_v443 VALUES($1)$$;
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,currency text,provider_deleted_at timestamptz,normalized_payload jsonb,institution_code text,provider_account_ref text,posting_date date,signed_amount numeric,raw_hash text,occurred_at timestamptz);
CREATE TABLE public.fixture_positions_v443(user_id uuid,data jsonb);
CREATE FUNCTION public.lts_open_finance_checking_positions_v1(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT data FROM public.fixture_positions_v443 WHERE user_id=$1$$;
INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000001','transaction','BRL',NULL,'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','341','invented-checking',date '2030-03-10',123.45,repeat('a',64),timestamptz '2030-03-10 09:00:00+00');
INSERT INTO public.fixture_positions_v443 VALUES('00000000-0000-4000-8000-000000000001',jsonb_build_array(jsonb_build_object('source_id','00000000-0000-4000-8000-000000000042','account_ref','invented-checking','institution_code','341','as_of',timestamptz '2030-03-10 10:00:00+00')));
