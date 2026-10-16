#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('apply_plan', ROOT/'tests/prepare-apply-plan.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

def synthetic_lease():
    return [dict(signature=sig, definition_md5=m.MD5((ROOT/'baseline'/(sig.split('(')[0]+'.sql')).read_text()[:-1]),
        acl='{wealth_fixture_owner=X/wealth_fixture_owner}', owner='wealth_fixture_owner', security_definer=('checking' not in sig),
        config=['search_path=""','TimeZone=America/Sao_Paulo']) for sig in m.SIGNATURES]

class OfflinePlanTests(unittest.TestCase):
    def test_generates_conditional_apply_and_rollback_without_connection(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); lease=d/'lease.json'; lease.write_text(json.dumps(synthetic_lease()))
            result=m.prepare(lease,d/'private')
            self.assertFalse(result['executed'])
            for file in ('apply.sql','rollback.sql'):
                sql=(d/'private'/file).read_text()
                self.assertEqual(sql.count('CREATE OR REPLACE FUNCTION'),1)
                self.assertIn('BEGIN;',sql); self.assertTrue(sql.rstrip().endswith('COMMIT;'))
                self.assertIn('pg_advisory_xact_lock',sql)
                self.assertIn('CASH_LEASE_MISMATCH',sql); self.assertIn('CASH_POSTCHECK_MISMATCH',sql)
                self.assertIn('END $function$;\n',sql)
                self.assertNotRegex(sql,r'(?im)^\s*(GRANT|REVOKE|ALTER|UPDATE|INSERT|DELETE)\s')
                self.assertEqual((d/'private'/file).stat().st_mode & 0o777,0o600)
            self.assertIn(m.ADDITION,(d/'private/apply.sql').read_text())
            self.assertNotIn(m.ADDITION,(d/'private/rollback.sql').read_text())
    def test_single_do_contains_exact_ddl_without_transaction_control(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); lease=d/'lease.json'; lease.write_text(json.dumps(synthetic_lease()))
            m.prepare(lease,d/'private')
            for name,source in [('apply-single-do.sql','candidate'),('rollback-single-do.sql','baseline')]:
                sql=(d/'private'/name).read_text()
                self.assertEqual(sql.count('DO $wealth_cash_atomic$'),1)
                self.assertNotRegex(sql,r'(?m)^\s*(BEGIN|COMMIT|ROLLBACK);')
                self.assertNotIn('CREATE TEMP TABLE',sql)
                self.assertIn('pg_try_advisory_xact_lock',sql)
                self.assertIn('CASH_DEPLOYMENT_BUSY',sql)
                self.assertIn('CASH_LEASE_MISMATCH',sql); self.assertIn('CASH_POSTCHECK_MISMATCH',sql)
                embedded=sql.split('EXECUTE $wealth_cash_ddl$\n')[1].split('\n$wealth_cash_ddl$;')[0]
                self.assertEqual(embedded,(ROOT/source/'lts_browser_cash_today_v178.sql').read_text().rstrip()+';')
                self.assertTrue(sql.rstrip().endswith('$wealth_cash_atomic$;'))
    def test_stale_definition_is_rejected_offline(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); value=synthetic_lease(); value[0]['definition_md5']='0'*32
            lease=d/'lease.json'; lease.write_text(json.dumps(value))
            with self.assertRaisesRegex(ValueError,'does not match'):
                m.prepare(lease,d/'private')
            self.assertFalse((d/'private').exists())
    def test_missing_dependency_is_rejected_offline(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d); lease=d/'lease.json'; lease.write_text(json.dumps(synthetic_lease()[:-1]))
            with self.assertRaisesRegex(ValueError,'four-function'):
                m.prepare(lease,d/'private')
    def test_only_one_transport_newline_is_tolerated(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'function.sql'; text='synthetic canonical\n'
            p.write_text(text+'\n'); self.assertEqual(m.canonical_file(p,m.MD5(text)),text)
            p.write_text(text+'\n\n')
            with self.assertRaises(ValueError): m.canonical_file(p,m.MD5(text))
    def test_suite_has_seven_statement_terminators_and_no_live_lease(self):
        suite=subprocess.check_output(['python3',str(ROOT/'tests/prepare-postgres-suite.py')],text=True)
        self.assertEqual(suite.count('$function$;'),7)
        self.assertNotIn('backend-lease-',suite)
        self.assertIn('2031-02-13T09:13:11.456Z',suite)
        self.assertIn('wealth_cash_timestamp_synthetic',suite)
        self.assertIn('wealth_fixture_outsider',suite)

if __name__=='__main__': unittest.main()
