#!/usr/bin/env python3
"""Offline-only SQL plan generator. Never opens a database connection.

The lease is a private deployment input, intentionally excluded from this package.
Both generated files contain that lease and must stay out of public CI/artifacts.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = 'lts_browser_cash_today_v178()'
SIGNATURES = [TARGET, 'lts_open_finance_current_bank_position_v1(uuid)', 'lts_open_finance_checking_positions_v1(uuid)', 'lts_browser_cash_today_v242()']
ADDITION = "  'bank_positions',positions->'accounts',\n"
MD5 = lambda s: hashlib.md5(s.encode()).hexdigest()

def canonical_file(path, expected_md5):
    data = path.read_text()
    if MD5(data) == expected_md5:
        return data
    if data.endswith('\n') and MD5(data[:-1]) == expected_md5:
        return data[:-1]  # One transport-added newline only, verified against lease.
    raise ValueError('baseline file does not match definition lease: ' + path.name)

def literal(value):
    return "'" + value.replace("'", "''") + "'"

def plan(before, after, definition, kind):
    lease = literal(json.dumps(before, ensure_ascii=False, separators=(',', ':')))
    expected = literal(json.dumps(after, ensure_ascii=False, separators=(',', ':')))
    return f"""-- PREPARED ONLY: {kind}. Execution requires coordinator review and authorization.
-- PRIVATE deployment lease: never commit this generated file to a public repository.
-- Cooperative advisory lock plus exact definition/ACL/config checks; no grants changed.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '20s';
SELECT pg_advisory_xact_lock(hashtextextended('wealth_cash178_bank_positions_v1',0));
CREATE TEMP TABLE _wealth_cash_lease ON COMMIT DROP AS
 SELECT * FROM jsonb_to_recordset({lease}::jsonb)
 AS x(signature text,definition_md5 text,acl text,owner text,security_definer boolean,config jsonb);
DO $lease_check$
DECLARE e record; p record;
BEGIN
 IF (SELECT count(*) FROM _wealth_cash_lease)<>4 THEN RAISE EXCEPTION 'CASH_LEASE_INCOMPLETE'; END IF;
 FOR e IN SELECT * FROM _wealth_cash_lease LOOP
  SELECT q.oid,md5(pg_get_functiondef(q.oid)) definition_md5,q.proacl::text acl,pg_get_userbyid(q.proowner) owner,
   q.prosecdef security_definer,to_jsonb(q.proconfig) config INTO p
  FROM pg_proc q WHERE q.oid=to_regprocedure('public.'||e.signature);
  IF p.oid IS NULL OR p.definition_md5 IS DISTINCT FROM e.definition_md5 OR p.acl IS DISTINCT FROM e.acl
   OR p.owner IS DISTINCT FROM e.owner OR p.security_definer IS DISTINCT FROM e.security_definer OR p.config IS DISTINCT FROM e.config
  THEN RAISE EXCEPTION 'CASH_LEASE_MISMATCH'; END IF;
 END LOOP;
END $lease_check$;
CREATE TEMP TABLE _wealth_cash_identity ON COMMIT DROP AS
 SELECT e.signature,q.oid,q.proacl,q.proowner,q.prosecdef,q.proconfig,q.prorettype,q.proargtypes
 FROM _wealth_cash_lease e JOIN pg_proc q ON q.oid=to_regprocedure('public.'||e.signature);

{definition.rstrip().removesuffix(chr(59))};

DO $post_check$
DECLARE e record; p record;
BEGIN
 IF EXISTS(SELECT 1 FROM _wealth_cash_identity b LEFT JOIN pg_proc q ON q.oid=b.oid
  WHERE q.oid IS NULL OR q.proacl IS DISTINCT FROM b.proacl OR q.proowner IS DISTINCT FROM b.proowner
   OR q.prosecdef IS DISTINCT FROM b.prosecdef OR q.proconfig IS DISTINCT FROM b.proconfig
   OR q.prorettype IS DISTINCT FROM b.prorettype OR q.proargtypes IS DISTINCT FROM b.proargtypes)
 THEN RAISE EXCEPTION 'CASH_ACCESS_OR_SIGNATURE_CHANGED'; END IF;
 FOR e IN SELECT * FROM jsonb_to_recordset({expected}::jsonb)
  AS x(signature text,definition_md5 text,acl text,owner text,security_definer boolean,config jsonb) LOOP
  SELECT q.oid,md5(pg_get_functiondef(q.oid)) definition_md5,q.proacl::text acl,pg_get_userbyid(q.proowner) owner,
   q.prosecdef security_definer,to_jsonb(q.proconfig) config INTO p
  FROM pg_proc q WHERE q.oid=to_regprocedure('public.'||e.signature);
  IF p.oid IS NULL OR p.definition_md5 IS DISTINCT FROM e.definition_md5 OR p.acl IS DISTINCT FROM e.acl
   OR p.owner IS DISTINCT FROM e.owner OR p.security_definer IS DISTINCT FROM e.security_definer OR p.config IS DISTINCT FROM e.config
  THEN RAISE EXCEPTION 'CASH_POSTCHECK_MISMATCH'; END IF;
 END LOOP;
END $post_check$;
COMMIT;
"""


def plan_single_do(before, after, definition, kind):
    lease = literal(json.dumps(before, ensure_ascii=False, separators=(',', ':')))
    expected = literal(json.dumps(after, ensure_ascii=False, separators=(',', ':')))
    if '$wealth_cash_atomic$' in definition or '$wealth_cash_ddl$' in definition:
        raise ValueError('unexpected SQL delimiter in canonical definition')
    projection = """SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'signature',lease_row.signature,'oid',q.oid::text,'acl',q.proacl::text,'owner',q.proowner::text,
   'security_definer',q.prosecdef,'config',pg_catalog.to_jsonb(q.proconfig),
   'return_type',q.prorettype::text,'argtypes',q.proargtypes::text) ORDER BY lease_row.signature)
  FROM pg_catalog.jsonb_to_recordset(lease) AS lease_row(signature text)
  JOIN pg_catalog.pg_proc q ON q.oid=pg_catalog.to_regprocedure('public.'||lease_row.signature)"""
    return f"""-- PREPARED ONLY: {kind}; one atomic PostgreSQL statement for migration execution.
-- PRIVATE deployment lease: never commit this generated file to a public repository.
-- No transaction-control SQL, temp tables or journal writes. API journal is verified separately.
DO $wealth_cash_atomic$
DECLARE
 lease jsonb := {lease}::jsonb;
 expected jsonb := {expected}::jsonb;
 e record; p record; before_identity jsonb; after_identity jsonb;
BEGIN
 PERFORM pg_catalog.set_config('lock_timeout','5s',true);
 PERFORM pg_catalog.set_config('statement_timeout','20s',true);
 IF NOT pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('wealth_cash178_bank_positions_v1',0)) THEN
  RAISE EXCEPTION 'CASH_DEPLOYMENT_BUSY';
 END IF;
 IF pg_catalog.jsonb_array_length(lease)<>4 THEN RAISE EXCEPTION 'CASH_LEASE_INCOMPLETE'; END IF;
 FOR e IN SELECT * FROM pg_catalog.jsonb_to_recordset(lease)
  AS x(signature text,definition_md5 text,acl text,owner text,security_definer boolean,config jsonb) LOOP
  SELECT q.oid,pg_catalog.md5(pg_catalog.pg_get_functiondef(q.oid)) definition_md5,q.proacl::text acl,
   pg_catalog.pg_get_userbyid(q.proowner) owner,q.prosecdef security_definer,pg_catalog.to_jsonb(q.proconfig) config INTO p
  FROM pg_catalog.pg_proc q WHERE q.oid=pg_catalog.to_regprocedure('public.'||e.signature);
  IF p.oid IS NULL OR p.definition_md5 IS DISTINCT FROM e.definition_md5 OR p.acl IS DISTINCT FROM e.acl
   OR p.owner IS DISTINCT FROM e.owner OR p.security_definer IS DISTINCT FROM e.security_definer OR p.config IS DISTINCT FROM e.config
  THEN RAISE EXCEPTION 'CASH_LEASE_MISMATCH'; END IF;
 END LOOP;
 before_identity := ({projection});
 EXECUTE $wealth_cash_ddl$
{definition.rstrip().removesuffix(chr(59))};
$wealth_cash_ddl$;
 -- DDL_COMPLETE_POSTCHECK_FOLLOWS
 after_identity := ({projection});
 IF before_identity IS DISTINCT FROM after_identity THEN RAISE EXCEPTION 'CASH_ACCESS_OR_SIGNATURE_CHANGED'; END IF;
 FOR e IN SELECT * FROM pg_catalog.jsonb_to_recordset(expected)
  AS x(signature text,definition_md5 text,acl text,owner text,security_definer boolean,config jsonb) LOOP
  SELECT q.oid,pg_catalog.md5(pg_catalog.pg_get_functiondef(q.oid)) definition_md5,q.proacl::text acl,
   pg_catalog.pg_get_userbyid(q.proowner) owner,q.prosecdef security_definer,pg_catalog.to_jsonb(q.proconfig) config INTO p
  FROM pg_catalog.pg_proc q WHERE q.oid=pg_catalog.to_regprocedure('public.'||e.signature);
  IF p.oid IS NULL OR p.definition_md5 IS DISTINCT FROM e.definition_md5 OR p.acl IS DISTINCT FROM e.acl
   OR p.owner IS DISTINCT FROM e.owner OR p.security_definer IS DISTINCT FROM e.security_definer OR p.config IS DISTINCT FROM e.config
  THEN RAISE EXCEPTION 'CASH_POSTCHECK_MISMATCH'; END IF;
 END LOOP;
END
$wealth_cash_atomic$;
"""

def prepare(lease_path, out_dir):
    lease = json.loads(lease_path.read_text())
    if not isinstance(lease, list) or len(lease) != 4 or set(x.get('signature') for x in lease) != set(SIGNATURES):
        raise ValueError('expected exact four-function lease')
    for row in lease:
        if not isinstance(row.get('definition_md5'), str) or len(row['definition_md5']) != 32 or any(c not in '0123456789abcdef' for c in row['definition_md5']):
            raise ValueError('invalid definition hash')
    by_sig = {row['signature']: row for row in lease}
    canonical = {sig: canonical_file(ROOT / 'baseline' / (sig.split('(')[0]+'.sql'), by_sig[sig]['definition_md5']) for sig in SIGNATURES}
    baseline_file = (ROOT / 'baseline/lts_browser_cash_today_v178.sql').read_text()
    candidate_file = (ROOT / 'candidate/lts_browser_cash_today_v178.sql').read_text()
    if candidate_file.count(ADDITION) != 1 or candidate_file.replace(ADDITION, '') != baseline_file:
        raise ValueError('candidate is not the exact approved additive change')
    old = canonical[TARGET]
    marker = "  'computed_at',clock_timestamp(),'status','complete','cash',bank,'d0',d0,"
    if old.count(marker) != 1:
        raise ValueError('canonical insertion point mismatch')
    new = old.replace(marker, ADDITION+marker)
    post_lease = json.loads(json.dumps(lease))
    next(x for x in post_lease if x['signature']==TARGET)['definition_md5'] = MD5(new)
    out_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name, data in [('apply.sql',plan(lease,post_lease,new,'apply')),('rollback.sql',plan(post_lease,lease,old,'conditional rollback')),
        ('apply-single-do.sql',plan_single_do(lease,post_lease,new,'apply')),
        ('rollback-single-do.sql',plan_single_do(post_lease,lease,old,'conditional rollback'))]:
        path=out_dir/name; path.write_text(data); path.chmod(0o600)
    return {'baseline_definition_md5':MD5(old),'candidate_definition_md5':MD5(new),'generated':['apply.sql','rollback.sql','apply-single-do.sql','rollback-single-do.sql'],'executed':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lease-file',type=Path,required=True)
    parser.add_argument('--private-output-dir',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(prepare(args.lease_file,args.private_output_dir)))
