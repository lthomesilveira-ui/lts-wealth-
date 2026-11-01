-- Isolated PostgreSQL fixtures only. No tokens, credentials or production identities.
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT '00000000-0000-4000-8000-000000000001'::uuid$$;
GRANT USAGE ON SCHEMA auth,public TO authenticated,service_role,anon;
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid,institution_code text,resource_type text,currency text,
 provider_deleted_at timestamptz,provider_account_ref text,normalized_payload jsonb
);
INSERT INTO public.lts_open_finance_staging
SELECT ('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 '00000000-0000-4000-8000-000000000001','336','invoice','BRL',NULL,'invented-account',
 jsonb_build_object('due_date',make_date(2026,i,5)) FROM generate_series(1,3)i;
ALTER TABLE public.lts_open_finance_staging ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_sources ON public.lts_open_finance_staging FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
GRANT SELECT ON public.lts_open_finance_staging TO authenticated,service_role;
CREATE TABLE public.lts_card_due_rule_v290(user_id uuid,family text,effective_from date,due_day int,confirmed_at timestamptz,decision_source text);
GRANT SELECT ON public.lts_card_due_rule_v290 TO authenticated,service_role;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE FUNCTION public.lts_card_due_rule_changed_v290() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
 BEGIN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;RETURN NULL;END $$;
CREATE FUNCTION public.lts_card_transition_overlay_v370(uuid,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $2$$;
\i backend/qa/fixtures/v391_due_overlay_before.sql
;
CREATE FUNCTION public.qa_v391_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS NOT TRUE THEN RAISE EXCEPTION 'V391 failed: %',label;END IF;END $$;
CREATE TABLE public.qa_v391_output(label text PRIMARY KEY,payload jsonb);
