-- Minimal compatible schema, ONLY for a fresh disposable PostgreSQL 16 database.
-- Auth, RLS, grants, API exposure and the complete reader graph are out of scope.
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE TABLE public.usuario (id uuid PRIMARY KEY REFERENCES auth.users(id), email text NOT NULL);
CREATE TABLE public.lts_allowed_users (email text PRIMARY KEY, active boolean NOT NULL, role text NOT NULL);
CREATE TABLE public.accounts (id uuid PRIMARY KEY, institution text NOT NULL);
CREATE TABLE public.financial_events (
 id uuid NOT NULL, user_id uuid NOT NULL, account_id uuid, legacy_id text,
 legacy_index integer, event_date date NOT NULL, description_raw text,
 description_normalized text, amount numeric, nature text, category text,
 counterparty text, source text, status text, is_internal_transfer boolean,
 is_projection boolean, is_suppressed boolean, suppression_reason text,
 metadata jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT financial_events_pkey PRIMARY KEY(id),
 CONSTRAINT financial_events_account_id_fkey FOREIGN KEY(account_id) REFERENCES public.accounts(id) ON DELETE SET NULL,
 CONSTRAINT financial_events_user_id_fkey FOREIGN KEY(user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
 CONSTRAINT financial_events_user_id_legacy_id_key UNIQUE(user_id,legacy_id)
);
CREATE TABLE public.lts_projection_replacement_rule (
 id text NOT NULL, user_id uuid NOT NULL, action text, active boolean,
 reason text, date_to date, evidence jsonb, date_from date,
 created_at timestamptz, updated_at timestamptz, source_table text,
 account_exact text, replacement_ref text, description_exact text,
 replacement_source text,
 CONSTRAINT lts_projection_replacement_rule_pkey PRIMARY KEY(id),
 CONSTRAINT lts_projection_replacement_rule_user_id_fkey FOREIGN KEY(user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
 CONSTRAINT lts_projection_replacement_rule_action_check CHECK (action = ANY (ARRAY['suppress_legacy'::text, 'replace_legacy'::text]))
);
CREATE TABLE public.evento_base (id bigint PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES auth.users(id), idx integer, dados jsonb NOT NULL);
CREATE TABLE public.lts_read_cache_epoch_v242 (singleton boolean PRIMARY KEY, epoch bigint NOT NULL);
CREATE TABLE public.lts_v229_read_cache (id bigint PRIMARY KEY, user_id uuid, value jsonb);
