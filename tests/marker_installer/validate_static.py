#!/usr/bin/env python3
"""Static checks only: no PostgreSQL parser or database execution."""
from pathlib import Path
import ast,hashlib,json,re,subprocess,sys
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
 assert len(files)==len(set(files)) and all('private' not in f and '..' not in Path(f).parts for f in files)
 allowed={'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'}
 for f in files:
  text=(HERE/f).read_text()
  if f.endswith('.py'):ast.parse(text,filename=f)
  if f.endswith('.sql'):check_sql_lexical(text)
  assert set(re.findall(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',text,re.I))<=allowed,f
 m=json.loads((HERE/'generated/manifest.json').read_text())
 assert m['synthetic_only'] and not m['postgresql_executed_during_generation']
 assert m['sanitization_reversal_exact'] and m['baseline_diff_only_marker']
 assert m['function_contract_count']==71 and m['relation_contract_count']==49
 for f,h in m['files'].items():assert hashlib.sha256((HERE/'generated'/f).read_bytes()).hexdigest()==h,f
 old=(HERE/'generated/baseline-original-synthetic.sql').read_text();new=(HERE/'generated/baseline-candidate-synthetic.sql').read_text()
 a="(kind in ('Saúde','Educação','Vestuário') and person_final is null)";b="(kind='Educação' and person_final is null)"
 assert old.count(a)==new.count(b)==1 and old.replace(a,b)==new
 for action in ['apply','rollback']:
  sql=(HERE/'generated'/f'{action}-synthetic.sql').read_text()
  assert sql.count('ready constant boolean:=false;')==1
  assert sql.count('nineteen protected fields')==2
  assert sql.count('IS NOT TRUE) THEN')==2
  assert 'BEGIN ISOLATION LEVEL REPEATABLE READ;' in sql and sql.rstrip().endswith('COMMIT;')
  assert sql.count('UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1')==1
  assert 'global_homologation_invalidated' in sql and 'required_fresh_stages' in sql
  assert '__FUNCTIONS_ORIGINAL__' in sql and '__FUNCTIONS_INSTALLED__' in sql and '__RELATIONS__' in sql
  indexes=[sql.index(t) for t in ['IF NOT ready','SELECT epoch INTO STRICT','EXECUTE $definition$','UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1','INTO after_baseline','postinstall function identity','INSERT INTO public.lts_access_audit']]
  assert indexes==sorted(indexes)
 refusal=subprocess.run([sys.executable,str(HERE/'run_postgres17.py')],text=True,capture_output=True)
 assert refusal.returncode==2 and 'no database was contacted' in refusal.stderr
 print(json.dumps({'status':'static-passed','sql_execution':False,'postgresql_parser_used':False,'public_files':len(files),'baseline_entire_body_diff_exact':True,'published_templates_ready_false':True,'source_hashes':m['source_installer_sha256']},indent=2,sort_keys=True))
if __name__=='__main__':main()
