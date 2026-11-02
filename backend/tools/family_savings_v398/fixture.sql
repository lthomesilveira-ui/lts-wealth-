CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULL::uuid $$;
CREATE TABLE public.financial_events(id uuid PRIMARY KEY,user_id uuid,metadata jsonb,status text,nature text,is_internal_transfer boolean DEFAULT false,is_suppressed boolean DEFAULT false);
CREATE TABLE public.test_bank_source(financial_event_id uuid,staging_id uuid,event_date date,signed_amount numeric);
CREATE FUNCTION public.lts_realized_bank_sources_v238(uuid) RETURNS SETOF public.test_bank_source LANGUAGE sql STABLE AS $$ SELECT * FROM public.test_bank_source $$;
CREATE FUNCTION public.lts_commitment_summary_overlay_v309(uuid,date,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT $3 $$;
CREATE FUNCTION public.lts_commitments_summary_v1(p_user_id uuid,p_as_of date DEFAULT CURRENT_DATE)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $fn$
WITH v309_previous(payload) AS(
 SELECT '{"version":"commitments-summary-v2-documentary","commitments":[{"id":"other","amount":88},{"id":"pai_mae","next_due":"2027-04-01","next_amount":25,"last_date":"2027-05-01","remaining_events":2,"remaining_scheduled_outflow":50,"schedule_rows":[{"due_date":"2027-04-01","amount":25,"status":"scheduled"},{"due_date":"2027-05-01","amount":25,"status":"scheduled"}],"unconfirmed_past_events":0}]}'::jsonb
)
SELECT public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload) FROM v309_previous;
$fn$;
-- Minimal public-HTTP/cron stubs in this isolated synthetic PostgreSQL database.
CREATE SCHEMA net;
CREATE TABLE net._http_response(id bigint,status_code integer,content text,timed_out boolean,error_msg text);
CREATE FUNCTION net.http_get(url text,params jsonb DEFAULT '{}',headers jsonb DEFAULT '{}',timeout_milliseconds integer DEFAULT 1000)
RETURNS bigint LANGUAGE sql AS $$ SELECT 7001::bigint $$;
CREATE SCHEMA cron;
CREATE TABLE cron.job(jobname text,schedule text,command text);
CREATE FUNCTION cron.schedule(p_name text,p_schedule text,p_command text) RETURNS bigint LANGUAGE plpgsql AS $$ BEGIN INSERT INTO cron.job VALUES(p_name,p_schedule,p_command);RETURN 1;END $$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE FUNCTION public.lts_backup_modern_export_v380(p_user_id uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('format','lts-modern-supplement-v380','tables',jsonb_build_object('old_fixture',jsonb_build_array('preserved')),'coverage',jsonb_build_object('selected_tables',1,'all_application_tables',false),'schema_columns','[]'::jsonb);
$$;
