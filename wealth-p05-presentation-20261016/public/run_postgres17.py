#!/usr/bin/env python3
"""Explicitly synthetic loopback PostgreSQL17 runner. No production URL supported."""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--allow-fresh-synthetic-postgres17',action='store_true')
args=parser.parse_args()
if not args.allow_fresh_synthetic_postgres17:parser.error('Requires disposable PostgreSQL17 opt-in; no connection attempted')
for script in ['build_candidate.py','build_tests.py','build_shared_policy_test.py','build_acl_test.py','validate_static.py']:
 subprocess.run([sys.executable,str(root/script)],check=True)
env=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT='5432',PGDATABASE='lts_p05_synthetic',PGUSER='lts_p05_synthetic',PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null')
result=subprocess.run(['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1','--file',str(root/'synthetic-presentation-acl-test.sql')],env=env,text=True,capture_output=True)
out=root/'results';out.mkdir(exist_ok=True)
(out/'postgres17.stdout.log').write_text(result.stdout);(out/'postgres17.stderr.log').write_text(result.stderr)
rows=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
expected=json.loads((root/'test-cases.json').read_text())['pure_sql_cases'];stages={x.get('stage'):x for x in rows}
okay=(result.returncode==0 and set(stages)=={'pure','shared_policy','acl','integration'} and stages['pure'].get('cases')==expected and stages['pure'].get('passed')==expected and stages['shared_policy'].get('cases',0)>60 and stages['shared_policy'].get('cases')==stages['shared_policy'].get('passed') and stages['acl'].get('cases')==10 and stages['acl'].get('passed')==10 and stages['integration'].get('passed') is True)
receipt={'status':'passed' if okay else 'failed','returncode':result.returncode,'candidate_sha256':hashlib.sha256((root/'payment-refresh-annotation.sql').read_bytes()).hexdigest(),'pure_expected':expected,'stages':rows,'production_contacted':False,'database':'fresh-local-synthetic-only'}
(out/'result.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
if result.stderr:print(result.stderr,file=sys.stderr)
sys.exit(0 if okay else 1)
