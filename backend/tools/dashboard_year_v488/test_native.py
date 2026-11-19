"""Exercise the shipped migration against a disposable PostgreSQL database."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
schema = 'lts_product_refresh_private_v415'
owner = '00000000-0000-0000-0000-000000000488'
engine = 'public.lts_browser_expenses_v229_engine_v251(date,date)'
reader = 'public.lts_browser_expenses_v229(date,date)'
runner = f'{schema}.run_claimed()'


def sql(command):
    return subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], input=command,
                          text=True, check=True, capture_output=True).stdout.strip()


def digest(signature):
    return sql(f"SET search_path=''; SELECT md5(pg_get_functiondef('{signature}'::regprocedure))")


sql(f"""
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE SCHEMA {schema};
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,
 refreshed_at timestamptz,source_fingerprint text,PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE sql AS $$SELECT '{owner}'::uuid$$;
CREATE FUNCTION public.lts_browser_expenses_v229_engine_v251(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
return jsonb_build_object('owner',u,'from',p_from,'to',p_to);
end $$;
CREATE FUNCTION public.lts_expense_presentation_v353(uuid,date,date,jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('fixture.fail',true)='yes' THEN RAISE EXCEPTION 'fixture report failure'; END IF;
 RETURN jsonb_build_object('fixture',true);
END $$;
CREATE FUNCTION public.lts_browser_expenses_v229(p_from date,p_to date) RETURNS jsonb LANGUAGE sql AS $$
SELECT public.lts_browser_expenses_v229_engine_v251(p_from,p_to) ||
 jsonb_build_object('presentation',public.lts_expense_presentation_v353(public.lts_browser_assert_user_v1(),p_from,p_to,'{{}}'))
$$;
CREATE FUNCTION {schema}.run_claimed() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE audit_v442 jsonb; u uuid:='{owner}'; expected_epoch bigint:=7;
BEGIN
  -- Protect publication, briefly, against a concurrent committed source epoch.
  IF current_setting('fixture.superseded',true)='yes' THEN RETURN '"superseded"'::jsonb; END IF;
  -- Persist the summary already produced during this guarded refresh.
  RETURN '"ready"'::jsonb;
END $$;
""")
migration = (root / 'install.sql').read_text()
for signature, pin in ((engine, '7ffca84a1e548a64e845e9421ae06133'), (reader, 'f36b21764272fabd0fb8a08073d1aa3e'),
                       (runner, '71fd4b4ec3ec34a33df0a605c0e1a76b')):
    migration = migration.replace(pin, digest(signature))
# The installed public wrapper also carries a provenance guard in the worker.
# Get the fixture catalog's exact pg_get_functiondef digest under rollback,
# preserving the original function and permissions for the actual migration.
migration = migration.replace('579e0574f5ea7c0d702e591786d7f3f1',
  sql("BEGIN;" + migration + f"SELECT md5(pg_get_functiondef('{engine}'::regprocedure)); ROLLBACK;"))
sql('BEGIN;' + migration + 'COMMIT;')
report = f"public.lts_browser_expenses_v229(date_trunc('year',current_date)::date,current_date)"
assert sql(f"SELECT {runner}") == '"ready"'
assert sql(f"SELECT payload={report} AND source_fingerprint='expenses-v464:7:'||current_date::text FROM public.lts_v229_read_cache") == 't'
# A fresh row is reused. A stale one is replaced.
sql("UPDATE public.lts_v229_read_cache SET payload='{}'")
assert sql(f"SELECT {runner}") == '"ready"'
assert sql("SELECT payload='{}' FROM public.lts_v229_read_cache") == 't'
sql("UPDATE public.lts_v229_read_cache SET refreshed_at=now()-interval '31 minutes'")
assert sql(f"SELECT {runner}") == '"ready"'
assert sql(f"SELECT payload={report} FROM public.lts_v229_read_cache") == 't'
sql("DELETE FROM public.lts_v229_read_cache")
assert sql(f"SET fixture.superseded='yes'; SELECT {runner}") == '"superseded"'
assert sql("SELECT count(*) FROM public.lts_v229_read_cache") == '0'
assert sql(f"SET fixture.fail='yes'; SELECT {runner}") == '"ready"'
assert sql("SELECT count(*) FROM public.lts_v229_read_cache") == '0'
for role in ['anon', 'authenticated', 'service_role']:
    for signature in [f'{schema}.expense_engine_v488(uuid,date,date)', f'{schema}.store_dashboard_year_v488(uuid,bigint,jsonb)']:
        assert sql(f"SELECT has_function_privilege('{role}','{signature}','execute')") == 'f'
# A changed public calculation can never seed the old warm path.
sql("CREATE OR REPLACE FUNCTION public.lts_browser_expenses_v229(p_from date,p_to date) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
assert sql(f"SELECT {runner}") == '"ready"'
assert sql("SELECT count(*) FROM public.lts_v229_read_cache") == '0'
print('Year-to-date payload, freshness, epoch, superseded claim, optional failure, private access and drift verified.')
