#!/usr/bin/env python3
"""PROPOSED opt-in runner. Uses only committed synthetic SQL, never private builder inputs."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
GENERATED = HERE / 'generated'
GUARD = 'lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'
U = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
P = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
ACL = '{postgres=X/postgres,service_role=X/postgres}'
REPORT = {'status': 'not-run', 'phase': 'argument-check', 'tests': [], 'production_validated': False}
REPORT_PATH = None


def lit(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    global REPORT_PATH
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-fresh-synthetic-postgres17', action='store_true')
    parser.add_argument('--port', type=int, default=5432)
    parser.add_argument('--results-dir', type=Path, default=HERE / 'results')
    args = parser.parse_args()
    if not args.allow_fresh_synthetic_postgres17:
        parser.error('Explicit disposable-cluster opt-in required; no database was contacted')
    if not 1024 <= args.port <= 65535:
        parser.error('Only unprivileged loopback ports are accepted')
    REPORT_PATH = args.results_dir / 'result.json'
    REPORT['phase'] = 'artifact-validation'
    env = dict(PATH=os.environ.get('PATH', '/usr/bin:/bin'), LANG='C.UTF-8',
               PGHOST='127.0.0.1', PGPORT=str(args.port), PGDATABASE='lts_p05_synthetic',
               PGUSER='lts_p05_synthetic', PGPASSWORD='synthetic-ci-only',
               PGCONNECT_TIMEOUT='5', PSQLRC='/dev/null')
    command = ['psql', '-X', '-q', '-A', '-t', '--set=ON_ERROR_STOP=1']
    log = REPORT['tests']
    def sql(text, expect=None, role=True):
        result = subprocess.run(command, input=('SET ROLE lts_p05_synthetic;\n' if role else '') + text,
                                env=env, text=True, capture_output=True)
        if expect is not None:
            if result.returncode == 0 or expect not in result.stderr:
                raise AssertionError(f'Expected rejection {expect!r}; code={result.returncode}; {result.stderr}')
            return result.stdout.strip()
        if result.returncode != 0:
            raise RuntimeError(result.stderr)
        return result.stdout.strip()
    def read_json(text, role=True):
        return json.loads(sql(text, role=role))
    manifest = json.loads((GENERATED / 'manifest.json').read_text())
    if not manifest['synthetic_only'] or manifest['database_leases'] != 'PLACEHOLDERS_DO_NOT_RUN':
        raise AssertionError('Only synthetic template artifacts are accepted')
    for name, expected in manifest['files'].items():
        if hashlib.sha256((GENERATED / name).read_bytes()).hexdigest() != expected:
            raise AssertionError('Artifact hash mismatch: ' + name)
    fixture = json.loads((GENERATED / 'fixtures-synthetic.json').read_text())
    placeholders = fixture['hashes']
    REPORT['phase'] = 'preflight'
    preflight = read_json("""SELECT jsonb_build_object(
      'version',current_setting('server_version_num')::int,
      'user',current_user,'database',current_database(),
      'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),
      'public_objects',(SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace),
      'public_functions',(SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace),
      'fixture_roles',(SELECT count(*) FROM pg_roles WHERE rolname IN('anon','authenticated','service_role')));""", role=False)
    if (not 170000 <= preflight['version'] < 180000 or
        preflight['user'] != 'lts_p05_synthetic' or preflight['database'] != 'lts_p05_synthetic' or
        not preflight['superuser'] or preflight['public_objects'] or preflight['public_functions'] or preflight['fixture_roles']):
        raise RuntimeError('Fresh dedicated PostgreSQL17 cluster required: ' + json.dumps(preflight))
    REPORT['phase'] = 'bootstrap'
    sql((GENERATED / 'bootstrap-synthetic.sql').read_text(), role=False)
    REPORT['phase'] = 'measure-synthetic-leases'
    def fn(name):
        return read_json(f"SELECT jsonb_build_object('oid',oid,'owner',proowner::regrole::text,'acl',proacl::text,'definition_md5',md5(pg_get_functiondef(oid))) FROM pg_proc WHERE oid={lit('public.'+name)}::regprocedure;")
    hashes = {'functions': {name: fn(name) for name in placeholders['functions']}}
    hashes['table'] = read_json("SELECT jsonb_build_object('oid',oid::bigint,'owner',relowner::regrole::text,'acl',relacl::text,'rls',relrowsecurity,'force_rls',relforcerowsecurity) FROM pg_class WHERE oid='public.lts_card_settlement_expense_contract_v273'::regclass;")
    scalar_oid = read_json("SELECT oid::bigint FROM pg_class WHERE oid='public.lts_card_settlement_expense_contract_v273'::regclass;")
    if type(hashes['table']['oid']) is not int or hashes['table']['oid'] != scalar_oid:
        raise AssertionError('Table OID lease must be numeric and equal to scalar catalog OID')
    hashes['original_definition_md5'] = fn(GUARD)['definition_md5']
    original_oid = fn(GUARD)['oid']
    sql((GENERATED / 'guard-candidate-synthetic.sql').read_text())
    hashes['candidate_definition_md5'] = fn(GUARD)['definition_md5']
    sql((GENERATED / 'guard-original-synthetic.sql').read_text())
    if fn(GUARD)['oid'] != original_oid:
        raise AssertionError('CREATE OR REPLACE changed fixture guard identity')
    for name, entry in hashes['functions'].items():
        if entry['owner'] != 'postgres' or entry['acl'] != ACL:
            raise AssertionError('Unexpected fixture owner or ACL: ' + name)
    def substitute(text):
        # Catalog measurements replace only complete, unique placeholder literals.
        table_placeholder = lit(json.dumps(placeholders['table'], separators=(',', ':'), sort_keys=True)) + '::jsonb'
        table_measured = lit(json.dumps(hashes['table'], separators=(',', ':'), sort_keys=True)) + '::jsonb'
        if text.count(table_placeholder) != 2:
            raise AssertionError('Table metadata placeholder must appear exactly twice')
        text = text.replace(table_placeholder, table_measured)
        for key in ('original_definition_md5', 'candidate_definition_md5'):
            text = text.replace(lit(placeholders[key]), lit(hashes[key]))
        for name, placeholder in placeholders['functions'].items():
            entry = hashes['functions'][name]
            text = text.replace(lit(placeholder['definition_md5']), lit(entry['definition_md5']))
            text = text.replace(str(placeholder['oid']) + '::oid', str(entry['oid']) + '::oid')
        if any(str(entry['oid']) + '::oid' in text for entry in placeholders['functions'].values()):
            raise AssertionError('Unresolved OID placeholder')
        return text
    apply = substitute((GENERATED / 'apply-synthetic.sql').read_text())
    rollback = substitute((GENERATED / 'rollback-synthetic.sql').read_text())
    snapshot_query = """SELECT jsonb_build_object(
      'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton),
      'contract',(SELECT to_jsonb(c) FROM public.lts_card_settlement_expense_contract_v273 c WHERE user_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid AND payment_source_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid),
      'all_contracts',(SELECT jsonb_agg(to_jsonb(c) ORDER BY user_id,payment_source_id) FROM public.lts_card_settlement_expense_contract_v273 c),
      'functions',(SELECT jsonb_agg(jsonb_build_object('oid',p.oid,'definition',pg_get_functiondef(p.oid),'owner',p.proowner::regrole::text,'acl',p.proacl::text) ORDER BY p.oid) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace),
      'tables',(SELECT jsonb_agg(jsonb_build_object('name',relname,'rls',relrowsecurity,'acl',relacl::text,'owner',relowner::regrole::text) ORDER BY relname) FROM pg_class WHERE relnamespace='public'::regnamespace),
      'column_acl',(SELECT jsonb_agg(jsonb_build_object('name',attname,'acl',attacl::text) ORDER BY attnum) FROM pg_attribute WHERE attrelid='public.lts_card_settlement_expense_contract_v273'::regclass AND attnum>0),
      'staging',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),
      'link',(SELECT jsonb_agg(to_jsonb(l) ORDER BY id) FROM public.lts_card_documentary_payment_link_v272 l));"""
    def snapshot():
        return read_json(snapshot_query)
    def check_state(candidate, epoch):
        value = snapshot()
        expected = fixture['new' if candidate else 'old']
        if value['contract'] != expected or value['epoch'] != epoch:
            raise AssertionError('Contract or epoch mismatch')
        guard = fn(GUARD)
        if guard['definition_md5'] != hashes['candidate_definition_md5' if candidate else 'original_definition_md5']:
            raise AssertionError('Guard definition mismatch')
        if guard['oid'] != original_oid or guard['owner'] != 'postgres' or guard['acl'] != ACL:
            raise AssertionError('Guard identity/owner/ACL mismatch')
    def same_retry(name, statement):
        before = snapshot()
        sql(statement)
        if snapshot() != before:
            raise AssertionError(name + ' changed state')
        log.append({'case': name, 'passed': True})
    def rejected(name, statement, error, setup='', restore=''):
        if setup:
            sql(setup)
        before = snapshot()
        sql(statement, expect=error)
        if snapshot() != before:
            raise AssertionError(name + ' did not restore exact pre-attempt state')
        if restore:
            sql(restore)
        log.append({'case': name, 'passed': True, 'expected_rejection': error})
    REPORT['phase'] = 'runtime-gates'
    check_state(False, 700)
    numeric_table = lit(json.dumps(hashes['table'], separators=(',', ':'), sort_keys=True)) + '::jsonb'
    string_table_value = dict(hashes['table'], oid=str(hashes['table']['oid']))
    string_table = lit(json.dumps(string_table_value, separators=(',', ':'), sort_keys=True)) + '::jsonb'
    if apply.count(numeric_table) != 2:
        raise AssertionError('Expected two numeric table leases')
    rejected('string-oid-lease-same-digits-blocked', apply.replace(numeric_table, string_table), 'private table metadata changed')
    log.append({'case':'numeric-table-oid-equals-scalar-catalog','passed':True})
    sql(apply)
    check_state(True, 701)
    log.append({'case': 'apply-postcheck-epoch-once', 'passed': True})
    same_retry('apply-retry-no-epoch', apply)
    sql(rollback)
    check_state(False, 702)
    log.append({'case': 'rollback-restores-body-contract-and-epoch-once', 'passed': True})
    same_retry('rollback-retry-no-epoch', rollback)
    # All next failures begin in the original state. DO-statement rollback must be atomic.
    rejected('post-ddl-coverage-failure', "SET p05_fixture.fail_coverage='on';\n" + apply,
             'current evidence or coverage changed')
    rejected('post-ddl-consumer-failure', "SET p05_fixture.fail_consumer='on';\n" + apply,
             'scoped final consumer mismatch')
    rejected('post-ddl-unrelated-row-failure', "SET p05_fixture.fail_unrelated='on';\n" + apply,
             'unrelated rows changed')
    rejected('post-ddl-null-source-unrelated-failure', "SET p05_fixture.fail_null_unrelated='on';\n" + apply,
             'unrelated rows changed')
    rejected('post-ddl-installed-definition-failure',
             apply.replace(lit(hashes['candidate_definition_md5']), lit('f' * 32)),
             'installed definition mismatch')
    rejected('post-ddl-documentary-failure', apply, 'documentary evidence changed',
             "UPDATE public.lts_card_documentary_payment_link_v272 SET evidence='synthetic-changed';",
             "UPDATE public.lts_card_documentary_payment_link_v272 SET evidence='SYNTHETIC-EVIDENCE-NOT-A-REAL-DOCUMENT';")
    rejected('contract-lease-change-blocked', apply, 'contract or guard lease changed',
             "UPDATE public.lts_card_settlement_expense_contract_v273 SET revision='synthetic-tampered';",
             "UPDATE public.lts_card_settlement_expense_contract_v273 SET revision='synthetic-original';")
    rejected('guard-acl-change-blocked', apply, 'guard ACL/owner changed',
             f'GRANT EXECUTE ON FUNCTION public.{GUARD} TO anon;',
             f'REVOKE EXECUTE ON FUNCTION public.{GUARD} FROM anon;')
    rejected('private-table-acl-change-blocked', apply, 'private evidence ACL changed',
             'GRANT SELECT ON public.lts_card_settlement_expense_contract_v273 TO anon;',
             'REVOKE SELECT ON public.lts_card_settlement_expense_contract_v273 FROM anon;')
    rejected('table-force-rls-change-blocked', apply, 'private table metadata changed',
             'ALTER TABLE public.lts_card_settlement_expense_contract_v273 FORCE ROW LEVEL SECURITY;',
             'ALTER TABLE public.lts_card_settlement_expense_contract_v273 NO FORCE ROW LEVEL SECURITY;')
    rejected('column-evidence-access-change-blocked', apply, 'client column-level evidence access',
             'GRANT SELECT(payload) ON public.lts_card_settlement_expense_contract_v273 TO authenticated;',
             'REVOKE SELECT(payload) ON public.lts_card_settlement_expense_contract_v273 FROM authenticated;')
    dependency = 'lts_v229_expense_rows(uuid,date,date)'
    rejected('dependency-acl-change-blocked', apply, 'dependency lease changed',
             f'GRANT EXECUTE ON FUNCTION public.{dependency} TO anon;',
             f'REVOKE EXECUTE ON FUNCTION public.{dependency} FROM anon;')
    old_def = sql(f'SELECT pg_get_functiondef({lit("public."+dependency)}::regprocedure);') + ';\n'
    changed_def = old_def.replace("kind IN('expense','unrelated')", "kind IN('expense','unrelated','synthetic-never')")
    if changed_def == old_def:
        raise AssertionError('Failed to construct synthetic definition mutation')
    rejected('dependency-definition-change-blocked', apply, 'dependency lease changed',
             changed_def, old_def)
    rejected('guard-oid-lease-change-blocked',
             apply.replace(str(original_oid) + '::oid', '1::oid'),
             'function identity or owner changed')
    check_state(False, 702)
    # Recovery has the same lease gates and must stay atomic on a post-DDL failure.
    sql(apply)
    check_state(True, 703)
    rejected('recovery-post-ddl-documentary-failure', rollback, 'documentary evidence changed',
             "UPDATE public.lts_card_documentary_payment_link_v272 SET evidence='synthetic-changed';",
             "UPDATE public.lts_card_documentary_payment_link_v272 SET evidence='SYNTHETIC-EVIDENCE-NOT-A-REAL-DOCUMENT';")
    rejected('recovery-contract-lease-change-blocked', rollback, 'contract or guard lease changed',
             "UPDATE public.lts_card_settlement_expense_contract_v273 SET revision='synthetic-tampered';",
             "UPDATE public.lts_card_settlement_expense_contract_v273 SET revision='synthetic-candidate';")
    rejected('recovery-another-policy-adopter-blocked', rollback, 'another contract adopted policy',
             "INSERT INTO public.lts_card_settlement_expense_contract_v273 VALUES('ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid,'99999999-9999-4999-8999-999999999999'::uuid,true,'synthetic-other','{\"invoice_evidence_policy\":\"raw_except_updatedAt_v1\"}'::jsonb);",
             "DELETE FROM public.lts_card_settlement_expense_contract_v273 WHERE revision='synthetic-other';")
    sql(rollback)
    check_state(False, 704)
    same_retry('recovery-retry-after-failure-no-epoch', rollback)
    # Do not destroy a supplied instance automatically. CI disposes the entire fresh service.
    receipt = {'status': 'passed', 'database': 'fresh-local-synthetic-only',
               'server_version_num': preflight['version'], 'passed': len(log), 'tests': log,
               'source_builder_sha256': manifest['source_builder_sha256'],
               'template_files': manifest['files'], 'measured_fixture_hashes': hashes,
               'final_epoch': 704, 'production_validated': False}
    args.results_dir.mkdir(parents=True, exist_ok=True)
    (args.results_dir / 'result.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(json.dumps(receipt, indent=2, sort_keys=True))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        REPORT.update(status='failed', error=str(exc), passed=len(REPORT['tests']))
        if REPORT_PATH is not None:
            REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
            REPORT_PATH.write_text(json.dumps(REPORT, indent=2, sort_keys=True) + '\n')
        print(json.dumps(REPORT, sort_keys=True), file=sys.stderr)
        sys.exit(1)
