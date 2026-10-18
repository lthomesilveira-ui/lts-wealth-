-- CI only: this intentionally minimal schema belongs in a disposable database.
DO $fixture$
BEGIN
 IF current_database()<>'lts_bill_source_qa' OR to_regclass('public.lts_open_finance_staging') IS NOT NULL
 OR to_regprocedure('public.lts_current_received_card_bills_v263(uuid)') IS NOT NULL
 THEN RAISE EXCEPTION 'Refusing to initialize fixtures outside a fresh dedicated QA database';END IF;
 IF current_setting('server_version_num')::integer/10000<>17 THEN RAISE EXCEPTION 'PostgreSQL 17 required';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN;END IF;
END $fixture$;
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,resource_type text NOT NULL,
 provider_record_id text,provider_account_ref text,raw_payload jsonb,normalized_payload jsonb,
 posting_date date,institution_name text,institution_code text,provider_deleted_at timestamptz,
 currency text,signed_amount numeric,last_seen_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT '2026-09-01T00:00:00Z');
-- Family classification is outside this fixture. Exact fixture names are equal.
CREATE FUNCTION public.lts_card_family_v226(p_name text,p_bank text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path TO '' AS $family$ SELECT lower(p_name) $family$;
