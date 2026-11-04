#!/usr/bin/env python3
"""PROPOSED runner: explicit opt-in, fixed synthetic loopback target, no real credentials."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--allow-fresh-synthetic-postgres17', action='store_true')
parser.add_argument('--port', type=int, default=5432)
args = parser.parse_args()
if not args.allow_fresh_synthetic_postgres17:
    parser.error('Requires explicit --allow-fresh-synthetic-postgres17; no database was contacted')
if not 1024 <= args.port <= 65535:
    parser.error('Unprivileged loopback port required')
subprocess.run([sys.executable, str(HERE / 'build_synthetic_gate.py')], check=True)
# Do not inherit PG* service/host/options/password or any application/production environment.
env = dict(PATH=os.environ.get('PATH', '/usr/bin:/bin'), LANG='C.UTF-8',
           PGHOST='127.0.0.1', PGPORT=str(args.port), PGDATABASE='lts_p05_synthetic',
           PGUSER='lts_p05_synthetic', PGPASSWORD='synthetic-ci-only',
           PGCONNECT_TIMEOUT='5', PSQLRC='/dev/null')
command = ['psql', '-X', '-q', '-A', '-t', '--set=ON_ERROR_STOP=1',
           '--file', str(HERE / 'generated/synthetic-gate.sql')]
result = subprocess.run(command, env=env, text=True, capture_output=True)
output = HERE / 'results'
output.mkdir(exist_ok=True)
(output / 'postgres17.stdout.log').write_text(result.stdout)
(output / 'postgres17.stderr.log').write_text(result.stderr)
rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
manifest = json.loads((HERE / 'generated/manifest.json').read_text())
receipt = dict(status='passed' if result.returncode == 0 else 'failed',
               returncode=result.returncode, expected_tests=manifest['case_count'],
               candidate_sha256=manifest['candidate_sha256'], results=rows)
if result.returncode == 0 and (len(rows) != 1 or rows[0].get('tests') != manifest['case_count']
                             or rows[0].get('passed') != manifest['case_count']
                             or rows[0].get('failures') != []):
    receipt['status'] = 'failed-result-contract'
(output / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
if result.stderr:
    print(result.stderr, file=sys.stderr)
sys.exit(0 if receipt['status'] == 'passed' else 1)
