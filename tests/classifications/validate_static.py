#!/usr/bin/env python3
"""Offline structural/privacy checks. Never a PostgreSQL execution claim."""
import ast, hashlib, importlib.util, json, re, subprocess, sys
from pathlib import Path
HERE=Path(__file__).resolve().parent

def check_sql_lexical(text):
    # Check each dollar body recursively so an outer DO delimiter cannot hide bad quoting.
    stack = []
    i = 0
    while i < len(text):
        if text.startswith('--', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end + 1
            continue
        if text.startswith('/*', i):
            level = 1
            i += 2
            while level:
                if i >= len(text):
                    raise AssertionError('Unterminated block comment')
                if text.startswith('/*', i):
                    level += 1
                    i += 2
                elif text.startswith('*/', i):
                    level -= 1
                    i += 2
                else:
                    i += 1
            continue
        if text[i] in "'\"":
            quote = text[i]
            i += 1
            while i < len(text):
                if text[i] == quote:
                    if i + 1 < len(text) and text[i + 1] == quote:
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    i += 1
            else:
                raise AssertionError('Unterminated quoted string')
            continue
        match = re.match(r'\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$', text[i:])
        if match:
            token = match.group()
            end = text.find(token, i + len(token))
            if end < 0:
                raise AssertionError('Unterminated dollar quote ' + token)
            check_sql_lexical(text[i + len(token):end])
            i = end + len(token)
            continue
        if text[i] == '(':
            stack.append(i)
        elif text[i] == ')':
            if not stack:
                raise AssertionError('Unbalanced closing parenthesis')
            stack.pop()
        i += 1
    if stack:
        raise AssertionError('Unbalanced opening parenthesis')


def main():
 files=json.loads((HERE/'PUBLIC_FILES.json').read_text())['files']
 assert len(files)==len(set(files))
 assert all('private' not in n and not n.startswith('/') and '..' not in Path(n).parts for n in files)
 allowed_uuids={
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  *(f'11111111-1111-4111-8111-{i:012d}' for i in range(1,6))}
 for n in files:
  path=HERE/n;assert path.is_file(),n;text=path.read_text()
  if n.endswith('.py'):ast.parse(text,filename=n)
  if n.endswith('.sql'):check_sql_lexical(text)
  found=set(re.findall(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',text,re.I))
  assert found<=allowed_uuids, 'Non-synthetic UUID: '+n
  if n!='validate_static.py':assert not re.search(r'(?i)postgres(?:ql)?://|supabase\.(?:co|com)|service_role_key|api_key\s*=',text),n
 manifest=json.loads((HERE/'generated/manifest.json').read_text())
 assert manifest['synthetic_only'] and manifest['database_tests_executed'] is False
 for n,h in manifest['files'].items():assert hashlib.sha256((HERE/'generated'/n).read_bytes()).hexdigest()==h,n
 fixture=json.loads((HERE/'generated/fixtures-synthetic.json').read_text())
 assert len(fixture['targets'])==5 and len({t['source_ref'] for t in fixture['targets']})==5
 for action in ['apply','rollback']:
  text=(HERE/'generated'/f'{action}-synthetic.sql').read_text()
  assert 'IN SHARE ROW EXCLUSIVE MODE' in text
  assert text.count("RAISE EXCEPTION 'cache trigger binding changed'")==2
  assert text.count("RAISE EXCEPTION 'out-of-scope decisions changed'")==1
  assert text.count("RAISE EXCEPTION 'installment blast radius changed'")==2
  assert 'ON CONFLICT' not in text
  for lease in fixture['leases'].values():assert text.count("'"+lease+"'")==2
  assert 'raw_reference' not in re.search(r"e-ARRAY\[(.*?)\]",text).group(1)
  assert 'jsonb_array_elements(targets)t' not in text
 spec=importlib.util.spec_from_file_location('marker_runner',HERE/'marker/marker_runner.py')
 marker=importlib.util.module_from_spec(spec);spec.loader.exec_module(marker)
 proof=marker.verify_public_sources();check_sql_lexical(marker.build_marker_sql())
 refusal=subprocess.run([sys.executable,str(HERE/'run_postgres17.py')],capture_output=True,text=True)
 assert refusal.returncode==2 and 'no database was contacted' in refusal.stderr
 report={'status':'static-passed','sql_execution':False,'postgresql_parser_used':False,'public_files':len(files),'marker_source_verification':proof,'checks':['Python AST','SQL quote/delimiter balance','five synthetic target identities','real envelope invariant ordering and lease placeholders','synthetic UUID allowlist','no production URLs/credentials','marker export provenance','runner rejects absent opt-in']}
 print(json.dumps(report,indent=2,sort_keys=True))
if __name__=='__main__':main()
