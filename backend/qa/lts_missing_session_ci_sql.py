"""Native negative-access contract. Synthetic rows only; no JWT or claims."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
reader=(ROOT/'backend/qa/lts_missing_session_read_probe.sql').read_text()
rows=(ROOT/'backend/qa/lts_missing_session_rows_probe.sql').read_text()
print(r"""
CREATE SCHEMA auth;
CREATE SCHEMA storage;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT NULL::uuid$$;
GRANT USAGE ON SCHEMA auth,storage TO anon,authenticated;
CREATE FUNCTION public.fixture_assert_user() RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='unauthorized';END $$;
CREATE TABLE public.fixture_side_effect(marker text);
CREATE FUNCTION public.lts_browser_open_finance_refresh_v1() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN INSERT INTO public.fixture_side_effect VALUES('must not be called');RETURN '{}'::jsonb;END $$;
CREATE FUNCTION public.lts_browser_cash_today_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;
CREATE FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;
CREATE FUNCTION public.lts_browser_expense_executive_v9(date,date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;
CREATE FUNCTION public.lts_browser_expense_executive_v10(date,date) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$
SELECT public.lts_browser_expense_executive_v9($1,$2)$$;
CREATE FUNCTION public.lts_browser_card_detail_v226(text,date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;
CREATE FUNCTION public.lts_browser_flow_v242(date,date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;
CREATE TABLE public.accounts(user_id uuid,amount numeric);
CREATE TABLE public.evento_base(usuario_id uuid,idx integer);
CREATE TABLE public.lts_fixture_private(user_id uuid);
CREATE TABLE public.lts_fixture_shared(user_id uuid,label text);
CREATE TABLE public.health_fixture(user_id uuid);
CREATE TABLE public.lts_health_fixture(user_id uuid);
CREATE TABLE storage.buckets(id text,public boolean);
CREATE TABLE storage.objects(bucket_id text,owner_id uuid);
INSERT INTO public.accounts VALUES('00000000-0000-4000-8000-000000000001',100);
INSERT INTO public.evento_base VALUES('00000000-0000-4000-8000-000000000001',1);
INSERT INTO public.lts_fixture_private VALUES('00000000-0000-4000-8000-000000000001');
INSERT INTO public.lts_fixture_shared VALUES(NULL,'allowed shared row'),('00000000-0000-4000-8000-000000000001','private row');
INSERT INTO public.health_fixture VALUES('00000000-0000-4000-8000-000000000001');
INSERT INTO public.lts_health_fixture VALUES('00000000-0000-4000-8000-000000000001');
INSERT INTO storage.buckets VALUES('lts-documents',false),('lts-web',false),('health-inbox',true);
INSERT INTO storage.objects VALUES('lts-documents','00000000-0000-4000-8000-000000000001'),('lts-web','00000000-0000-4000-8000-000000000001');
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_fixture_private ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_fixture_shared ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_accounts ON public.accounts FOR SELECT USING(user_id=auth.uid());
CREATE POLICY own_events ON public.evento_base FOR SELECT USING(usuario_id=auth.uid());
CREATE POLICY own_or_shared ON public.lts_fixture_shared FOR SELECT USING(user_id IS NULL OR user_id=auth.uid());
CREATE POLICY own_objects ON storage.objects FOR SELECT USING(owner_id=auth.uid());
GRANT SELECT ON public.accounts,public.evento_base,public.lts_fixture_shared,public.health_fixture,public.lts_health_fixture,storage.objects TO anon,authenticated;
REVOKE ALL ON public.lts_fixture_private FROM PUBLIC,anon,authenticated;
CREATE VIEW public.lts_fixture_owner_view WITH(security_invoker=true) AS SELECT * FROM public.accounts;
GRANT SELECT ON public.lts_fixture_owner_view TO anon,authenticated;
""")

def probe(sql,setting,expected,count):
    original=f"SELECT current_setting('{setting}')::jsonb receipt;"
    assert sql.count(original)==1
    check=f"""
DO $assert$
DECLARE j jsonb:=current_setting('{setting}')::jsonb;
BEGIN
 IF (j->>'pass')::boolean IS DISTINCT FROM {str(expected).lower()} THEN RAISE EXCEPTION 'Unexpected probe result: %',j;END IF;
 IF coalesce((j->>'financial_read_functions')::integer,(j->>'relation_role_cases')::integer)<>{count}
 THEN RAISE EXCEPTION 'Unexpected probe coverage';END IF;
 IF (j->>'claims_modified')::boolean OR (j->>'source_mutations')::boolean OR (j->>'signed_http_identity_test')::boolean
 THEN RAISE EXCEPTION 'Probe trust boundary changed';END IF;
 IF EXISTS(SELECT 1 FROM public.fixture_side_effect) THEN RAISE EXCEPTION 'Mutating RPC was called';END IF;
END $assert$;
"""
    print(sql.replace(original,check))

probe(reader,'lts.missing_session_probe',True,6)
probe(rows,'lts.missing_session_rows_probe',True,12)

# An accessible read must fail the audit, even when it only returns an empty JSON object.
print("CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$BEGIN RETURN '{}'::jsonb;END $$;")
probe(reader,'lts.missing_session_probe',False,6)
# Business validation is not an authorization rejection.
print("CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$BEGIN RAISE EXCEPTION 'invalid period';END $$;")
probe(reader,'lts.missing_session_probe',False,6)
# A read-only violation is not accepted as proof of an authorization guard.
print("CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$BEGIN INSERT INTO public.fixture_side_effect VALUES('bad read');RETURN '{}'::jsonb;END $$;")
probe(reader,'lts.missing_session_probe',False,6)
print("CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$BEGIN PERFORM public.fixture_assert_user();RETURN '{}'::jsonb;END $$;")
probe(reader,'lts.missing_session_probe',True,6)

print("CREATE TABLE public.lts_fixture_unprotected(user_id uuid);INSERT INTO public.lts_fixture_unprotected VALUES('00000000-0000-4000-8000-000000000001');GRANT SELECT ON public.lts_fixture_unprotected TO anon,authenticated;")
probe(rows,'lts.missing_session_rows_probe',False,14)
print("DROP TABLE public.lts_fixture_unprotected;")
print("ALTER VIEW public.lts_fixture_owner_view SET(security_invoker=false);")
probe(rows,'lts.missing_session_rows_probe',False,12)
print("ALTER VIEW public.lts_fixture_owner_view SET(security_invoker=true);")
print("UPDATE storage.buckets SET public=true WHERE id='lts-documents';")
probe(rows,'lts.missing_session_rows_probe',False,12)
print("UPDATE storage.buckets SET public=false WHERE id='lts-documents';")
probe(rows,'lts.missing_session_rows_probe',True,12)

print("REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated;")
probe(reader,'lts.missing_session_probe',False,0)
print("GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;")
probe(reader,'lts.missing_session_probe',True,6)

print(r"""
DO $final$
BEGIN
 IF EXISTS(SELECT 1 FROM public.fixture_side_effect) OR (SELECT count(*) FROM public.accounts)<>1
 OR (SELECT count(*) FROM public.evento_base)<>1 OR (SELECT count(*) FROM public.lts_fixture_private)<>1
 OR (SELECT count(*) FROM public.lts_fixture_shared)<>2 OR (SELECT count(*) FROM public.health_fixture)<>1
 OR (SELECT count(*) FROM public.lts_health_fixture)<>1 OR (SELECT count(*) FROM storage.objects)<>2
 THEN RAISE EXCEPTION 'Fixture source data changed';END IF;
END $final$;
SELECT jsonb_build_object('pass',true,'positive_read_rpc_cases',6,'positive_relation_role_cases',12,
 'injected_failure_cases',7,'claims_modified',false,'financial_writers_called',false,
 'empty_read_coverage_rejected',true,
 'read_only_violation_not_auth_pass',true,'business_error_not_auth_pass',true,
 'unguarded_reader_detected',true,'unprotected_table_detected',true,'definer_view_detected',true,
 'public_financial_bucket_detected',true,'health_excluded',true,'shared_rows_not_misclassified',true,
 'fixture_source_rows_preserved',true,'synthetic_data_only',true,'signed_http_identity_test',false) receipt;
""")
