#!/usr/bin/env python3
"""Build the self-contained fixture suite. Does not connect to any database."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text()
statement = lambda sql: sql.rstrip().removesuffix(';') + ';\n'
parts = [read('tests/postgres-fixtures.sql')]
sources = ['lts_open_finance_checking_positions_v1', 'lts_open_finance_current_bank_position_v1', 'lts_browser_cash_today_v178', 'lts_browser_cash_today_v242']
for name in sources:
    parts.append(statement(read(f'baseline/{name}.sql')))
for version in ('178', '242'):
    sql = read(f'baseline/lts_browser_cash_today_v{version}.sql')
    sql = sql.replace(f'public.lts_browser_cash_today_v{version}()', f'public.lts_browser_cash_today_v{version}_before()')
    if version == '242':
        sql = sql.replace('public.lts_browser_cash_today_v178()', 'public.lts_browser_cash_today_v178_before()')
    parts.append(statement(sql))
for name in sources + ['lts_browser_cash_today_v178_before', 'lts_browser_cash_today_v242_before']:
    arg = 'uuid' if 'open_finance_' in name else ''
    sig = f'public.{name}({arg})'
    parts.append(f'ALTER FUNCTION {sig} OWNER TO wealth_fixture_owner;\nREVOKE ALL ON FUNCTION {sig} FROM PUBLIC;')
    if 'browser_cash' in name:
        parts.append(f'GRANT EXECUTE ON FUNCTION {sig} TO wealth_fixture_browser;')
parts.append("""
CREATE TABLE wealth_test.function_metadata_before AS
 SELECT p.oid,p.oid::regprocedure::text signature,pg_get_functiondef(p.oid) definition,p.proacl,p.proowner,p.prosecdef,p.proconfig,p.prorettype,p.proargtypes
 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
 WHERE n.nspname='public' AND p.proname IN ('lts_browser_cash_today_v178','lts_browser_cash_today_v242','lts_open_finance_current_bank_position_v1','lts_open_finance_checking_positions_v1');
""")
parts.append(statement(read('candidate/lts_browser_cash_today_v178.sql')))
parts.append("""
SELECT wealth_test.assert_true((SELECT count(*) FROM wealth_test.function_metadata_before)=4,'four function leases captured');
SELECT wealth_test.assert_true(NOT EXISTS(
 SELECT 1 FROM wealth_test.function_metadata_before b LEFT JOIN pg_proc p ON p.oid=b.oid
 WHERE p.oid IS NULL OR p.proacl IS DISTINCT FROM b.proacl OR p.proowner IS DISTINCT FROM b.proowner OR p.prosecdef IS DISTINCT FROM b.prosecdef
 OR p.proconfig IS DISTINCT FROM b.proconfig OR p.prorettype IS DISTINCT FROM b.prorettype OR p.proargtypes IS DISTINCT FROM b.proargtypes
),'OID ACL owner definer configuration and signature preserved');
SELECT wealth_test.assert_true(NOT EXISTS(
 SELECT 1 FROM wealth_test.function_metadata_before b WHERE b.oid<>'public.lts_browser_cash_today_v178()'::regprocedure
 AND pg_get_functiondef(b.oid) IS DISTINCT FROM b.definition
),'three dependencies are byte-for-byte unchanged');
SELECT wealth_test.assert_true((
 SELECT replace(pg_get_functiondef(b.oid), E'  ''bank_positions'',positions->''accounts'',\\n','')=b.definition
 FROM wealth_test.function_metadata_before b WHERE b.oid='public.lts_browser_cash_today_v178()'::regprocedure
),'canonical function body differs by one property only');
DO $$ DECLARE started timestamptz:=clock_timestamp(); j jsonb; finished timestamptz;
BEGIN j:=public.lts_browser_cash_today_v178(); finished:=clock_timestamp();
 PERFORM wealth_test.assert_true(jsonb_typeof(j->'computed_at')='string' AND (j->>'computed_at')::timestamptz BETWEEN started AND finished,'computed_at remains actual computation time');
END $$;
""")
parts.append(read('tests/postgres-assertions.sql'))
text = '\n\n'.join(parts)
if len(sys.argv) == 2:
    Path(sys.argv[1]).write_text(text)
else:
    print(text)
