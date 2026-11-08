CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(
 user_id uuid NOT NULL,kind text NOT NULL,as_of date NOT NULL,from_date date NOT NULL,to_date date NOT NULL,
 payload jsonb NOT NULL,source_fingerprint text,refreshed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date)
);
REVOKE ALL ON public.lts_v229_read_cache FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.lts_v229_read_cache,public.lts_read_cache_epoch_v242 TO service_role;
CREATE FUNCTION public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)
RETURNS TABLE(event_date date,account text,description text,signed_amount numeric,source text,
 source_ref text,confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean)
LANGUAGE sql AS $$ SELECT current_date,'Synthetic Bank','Synthetic cash',42::numeric,'fixture','cash',
 'documented','assigned',1,current_date,false $$;
CREATE FUNCTION public.lts_payroll_bank_matches_v231_engine_v243(uuid)
RETURNS TABLE(projection_ref text,projection_date date,projection_amount numeric,staging_id uuid,
 actual_date date,actual_amount numeric,bank text)
LANGUAGE sql AS $$ SELECT 'synthetic-pay',current_date,11::numeric,'10000000-0000-4000-8000-000000000001'::uuid,
 current_date,11::numeric,'Synthetic Bank' $$;
CREATE FUNCTION public.lts_card_invoice_amounts_v230_engine_v243(uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql AS $$ SELECT $1,'synthetic-card',date_trunc('month',current_date)::date,current_date,'open',17::numeric,'fixture' $$;
CREATE FUNCTION public.lts_card_projection_rows_v290(uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql AS $$ SELECT $1,'unused',current_date,current_date,'projected',0::numeric,'fixture' WHERE false $$;
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT $1$$;
CREATE FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE FUNCTION public.lts_card_projection_date_v370(uuid,text,date,date,date) RETURNS date LANGUAGE sql AS $$SELECT $4$$;
CREATE FUNCTION public.lts_card_transition_cash_date_v370(uuid,text,date) RETURNS date LANGUAGE sql AS $$SELECT $3$$;
CREATE TABLE public.lts_card_due_transition_v370(user_id uuid,family text);
CREATE FUNCTION public.lts_current_received_card_bills_v263(uuid)
RETURNS TABLE(family text,reference_month date) LANGUAGE sql AS $$SELECT 'unused',current_date WHERE false$$;
\ir fixtures/v430/lts_corrected_cashflow_fix86_v1.sql
\ir fixtures/v430/lts_card_invoice_amounts_v230.sql
\ir fixtures/v430/lts_payroll_bank_matches_v231.sql
REVOKE ALL ON FUNCTION public.lts_corrected_cashflow_fix86_v1(uuid,date,date),
 public.lts_card_invoice_amounts_v230(uuid),public.lts_payroll_bank_matches_v231(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_corrected_cashflow_fix86_v1(uuid,date,date),
 public.lts_card_invoice_amounts_v230(uuid),public.lts_payroll_bank_matches_v231(uuid) TO service_role;
CREATE TABLE v430_attributes AS SELECT oid,to_jsonb(p)-'prosrc' attributes FROM pg_proc p WHERE p.oid IN(
 'public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure,
 'public.lts_card_invoice_amounts_v230(uuid)'::regprocedure,'public.lts_payroll_bank_matches_v231(uuid)'::regprocedure);
