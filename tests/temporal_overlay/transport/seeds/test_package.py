"""Offline tests only. Does not execute SQL or contact any service."""
from copy import deepcopy
from pathlib import Path
import hashlib,json,subprocess,sys,tempfile,unittest
from overlay_reference import result
from verify_results import verify,strict_load,exact,VerificationError
from run_pg17 import parse_pg_meta,validate_target,package_check,VerificationError as RunnerError
ROOT=Path(__file__).parent
INPUTS=strict_load((ROOT/'inputs.json').read_text());EXPECTED=strict_load((ROOT/'expected.json').read_text())

class OracleContract(unittest.TestCase):
    def test_85_explicit_oracles(self):
        self.assertEqual(len(INPUTS),85)
        oracle={c['case_id']:c['result'] for c in EXPECTED}
        for c in INPUTS:
            with self.subTest(case=c['case_id']): exact(result(c['input']),oracle[c['case_id']])
    def test_no_inputs_mutated(self):
        before=deepcopy(INPUTS)
        for c in INPUTS: result(c['input'])
        exact(INPUTS,before)
    def test_baseline_28_10_changes_unchanged(self):
        b=strict_load((ROOT/'baseline-28.json').read_text())
        self.assertEqual([c['case_id'] for c in INPUTS[:28]],b['cases'])
        rows=[r for c in EXPECTED[:28] for r in c['result']['obligations']]
        self.assertEqual([{'event_id':r['event_id'],'due':r['due']} for r in rows],b['expected'])
        self.assertEqual(sum(d['changed_due'] for c in EXPECTED[:28] for d in c['result']['decisions']),10)
        self.assertEqual(sum(len(c['input']['bills']) for c in INPUTS[:28]),37)
    def test_verifier_complete_pass(self):
        report=verify(EXPECTED,INPUTS,EXPECTED)
        self.assertIs(report['verified'],True);self.assertEqual(report['cases'],85)
    def test_frozen_expected_is_independent_of_reference(self):
        source=(ROOT/'build_cases.py').read_text()
        self.assertNotIn('overlay_reference',source);self.assertNotIn('result(',source)
    def test_rebuild_is_byte_reproducible(self):
        paths=['inputs.json','expected.json','case-catalog.json','overlay_contract.sql']
        before={x:hashlib.sha256((ROOT/x).read_bytes()).hexdigest() for x in paths}
        for script in ('build_cases.py','build_sql.py'):
            subprocess.run([sys.executable,str(ROOT/script)],check=True,capture_output=True)
        self.assertEqual(before,{x:hashlib.sha256((ROOT/x).read_bytes()).hexdigest() for x in paths})

class VerifierCounterexamples(unittest.TestCase):
    def rejects(self,mutation):
        a=deepcopy(EXPECTED);mutation(a)
        with self.assertRaises(VerificationError): verify(a,INPUTS,EXPECTED)
    def test_empty(self): self.rejects(lambda a:a.clear())
    def test_missing_case(self): self.rejects(lambda a:a.pop())
    def test_extra_case(self): self.rejects(lambda a:a.append({'case_id':'extra','result':{}}))
    def test_duplicate_case(self): self.rejects(lambda a:a.append(deepcopy(a[0])))
    def test_missing_output(self): self.rejects(lambda a:a[0]['result']['obligations'].clear())
    def test_duplicated_output(self): self.rejects(lambda a:a[0]['result']['obligations'].append(deepcopy(a[0]['result']['obligations'][0])))
    def test_omitted_nested_field(self): self.rejects(lambda a:a[0]['result']['obligations'][0].pop('document_as_of'))
    def test_changed_financial_value(self): self.rejects(lambda a:a[0]['result']['obligations'][0].update(amount='101.00'))
    def test_changed_due(self): self.rejects(lambda a:a[0]['result']['obligations'][0].update(due='2035-12-03'))
    def test_changed_competence(self): self.rejects(lambda a:a[0]['result']['obligations'][0].update(reference_month='2035-12-01'))
    def test_missing_finding(self): self.rejects(lambda a:a[11]['result']['source_findings'].clear())
    def test_true_must_be_boolean(self):
        for bad in (None,'true','false',1,0):
            with self.subTest(bad=bad): self.rejects(lambda a:a[0]['result']['decisions'][0].update(changed_due=bad))
    def test_fake_pass_field_does_not_override(self): self.rejects(lambda a:a[0]['result'].update(passed=True))
    def test_invalid_json_duplicate_keys(self):
        for s in ('', '{}\n{}', '{"a":1,"a":1}', '[NaN]'):
            with self.subTest(s=s),self.assertRaises(VerificationError): strict_load(s)
    def test_arbitrary_json_numbers_are_exact(self):
        for a,b in [('9007199254740992.0','9007199254740992.1'),('1e999','2e999')]:
            with self.assertRaises(VerificationError): exact(strict_load(a),strict_load(b))
        exact(strict_load('1.0'),strict_load('1'))  # one JSON numeric value
    def test_duplicate_input_case_is_rejected(self):
        with self.assertRaises(VerificationError): verify(EXPECTED,INPUTS+[deepcopy(INPUTS[0])],EXPECTED)
    def test_missing_decisions_rejected_even_with_bad_oracle(self):
        a=deepcopy(EXPECTED);a[0]['result']['decisions']=[]
        with self.assertRaises(VerificationError): verify(a,INPUTS,a)
    def test_deep_protected_mutation(self):
        for field,value in [('audit_payload',{}),('bill_key',None),('source_updated',None),('due','2036-01-03')]:
            def mutate(a):
                next(c for c in a if c['case_id']=='protected_deep_conflict')['result']['obligations'][0][field]=value
            with self.subTest(field=field): self.rejects(mutate)

class RunnerGates(unittest.TestCase):
    def test_pg17_meta_only(self):
        good={'server_version_num':170010,'socket_only':True,'read_only':True}
        self.assertEqual(parse_pg_meta(json.dumps(good)),good)
        for f,v in [('server_version_num',160000),('server_version_num',180000),('server_version_num','170001'),('socket_only',False),('socket_only','true'),('read_only',None)]:
            bad=good|{f:v}
            with self.subTest(f=f,v=v),self.assertRaises(RunnerError): parse_pg_meta(json.dumps(bad))
    def test_no_implicit_or_remote_target(self):
        for socket in ('localhost','127.0.0.1','/var/run/postgresql','/tmp/nonexistent-overlay-test'):
            with self.subTest(socket=socket),self.assertRaises(RunnerError): validate_target(socket,'overlay_pg17_test','postgres',55432,True)
    def test_explicit_local_disposable_only(self):
        with tempfile.TemporaryDirectory(prefix='overlay-test-') as d:
            self.assertEqual(validate_target(d,'overlay_pg17_test','postgres',55432,True),Path(d).resolve())
            for database,user,port,ack in [('postgres','postgres',55432,True),('overlay_pg17_test','x service=prod',55432,True),('overlay_pg17_test','postgres',543,True),('overlay_pg17_test','postgres',55432,False)]:
                with self.assertRaises(RunnerError): validate_target(d,database,user,port,ack)
    def test_manifest_tamper_missing_extra_and_pin_fail_closed(self):
        with tempfile.TemporaryDirectory(prefix='overlay-manifest-test-') as d:
            r=Path(d);member=r/'file.py';member.write_text('synthetic')
            manifest={'format':'overlay_pg17_package_v1','files':[{'path':'file.py','sha256':hashlib.sha256(member.read_bytes()).hexdigest()}],'synthetic_only':True,'pg_executed':False}
            (r/'PACKAGE_MANIFEST.json').write_text(json.dumps(manifest))
            pin=package_check(r)
            self.assertEqual(package_check(r,pin),pin)
            with self.assertRaises(RunnerError): package_check(r,'0'*64)
            member.write_text('tampered')
            with self.assertRaises(RunnerError): package_check(r)
            member.write_text('synthetic');(r/'extra.py').write_text('unreviewed')
            with self.assertRaises(RunnerError): package_check(r)
            (r/'extra.py').unlink();member.unlink()
            with self.assertRaises(RunnerError): package_check(r)
    def test_consumed_bytes_are_immutable_checked_snapshots(self):
        with tempfile.TemporaryDirectory(prefix='overlay-snapshot-test-') as d:
            r=Path(d);member=r/'file.py';member.write_text('reviewed')
            manifest={'format':'overlay_pg17_package_v1','files':[{'path':'file.py','sha256':hashlib.sha256(member.read_bytes()).hexdigest()}],'synthetic_only':True,'pg_executed':False}
            (r/'PACKAGE_MANIFEST.json').write_text(json.dumps(manifest))
            pin,snapshot=package_check(r,capture=True)
            member.write_text('concurrently changed')
            self.assertEqual(snapshot['file.py'],b'reviewed')
            with self.assertRaises(RunnerError): package_check(r,pin,capture=True)
        source=(ROOT/'run_pg17.py').read_text()
        for name in ('overlay_contract.sql','verify_results.py','inputs.json','expected.json'):
            self.assertIn("snapshots['"+name+"']",source)
    def test_verifier_loaded_after_integrity_without_cache(self):
        source=(ROOT/'run_pg17.py').read_text()
        self.assertNotIn('from verify_results import',source)
        self.assertIn("exec(compile(snapshots['verify_results.py']",source)
        self.assertLess(source.index('pin,snapshots=package_check('),source.index('exec(compile('))
    def test_same_session_guard_and_no_password(self):
        source=(ROOT/'run_pg17.py').read_text()
        for guard in ('ON_ERROR_STOP=1',"'-X'","'-w'",'PGPASSFILE','PGSERVICEFILE','target_ok','READ ONLY','statement_timeout','search_path=pg_catalog'):
            self.assertIn(guard,source)
    def test_sql_no_production_relation_or_write(self):
        sql=(ROOT/'overlay_contract.sql').read_text()
        sql=sql.split('$overlay_inputs$')[2]
        import re
        self.assertIsNone(re.search(r'\b(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|GRANT|COPY|CALL|DO)\b',sql,re.I))
        self.assertNotIn('public.',sql);self.assertNotIn('auth.',sql)
    def test_default_runner_never_executes(self):
        # Static guard: default exits before even target validation/subprocess.
        source=(ROOT/'run_pg17.py').read_text()
        self.assertLess(source.index('if not args.execute_local_pg17'),source.index('subprocess.run'))

if __name__=='__main__': unittest.main(verbosity=2)
