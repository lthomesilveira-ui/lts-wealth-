-- Minimal synthetic reader schema. Use only in the freshly generated QA database.
-- The debt-position column types, NOT NULLs, PK and per-user/date UNIQUE are
-- retained. No RLS, grants, cache triggers or complete production schema implied.
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE TABLE public.lts_debt_position (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 commitment_id text NOT NULL,
 as_of_date date NOT NULL,
 institution text,
 contract_ref text,
 debt_balance numeric,
 status text NOT NULL DEFAULT 'documented',
 source_label text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT lts_debt_position_user_id_commitment_id_as_of_date_key
   UNIQUE (user_id, commitment_id, as_of_date)
);
-- Only columns read by the function and its identity constraints are necessary.
CREATE TABLE public.lts_commitment_documentary_schedule (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 commitment_id text NOT NULL,
 installment_number integer NOT NULL,
 due_date date NOT NULL,
 amount_total numeric NOT NULL,
 principal numeric,
 interest numeric,
 balance_after numeric,
 status text NOT NULL,
 CONSTRAINT lts_commitment_documentary_sc_user_id_commitment_id_install_key
   UNIQUE (user_id, commitment_id, installment_number)
);
