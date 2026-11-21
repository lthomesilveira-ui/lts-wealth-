#!/usr/bin/env python3
"""Offline structural checks. This is not a PostgreSQL parser or database test."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent


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
    files = json.loads((HERE / 'PUBLIC_FILES.json').read_text())['files']
    assert 'build_envelope.py' not in files
    for name in files:
        assert (HERE / name).is_file(), name
        if name.endswith('.py'):
            ast.parse((HERE / name).read_text(), filename=name)
    manifest = json.loads((HERE / 'generated/manifest.json').read_text())
    assert manifest['synthetic_only'] is True
    assert manifest['database_tests_executed'] is False
    assert manifest['database_leases'] == 'PLACEHOLDERS_DO_NOT_RUN'
    for name, expected in manifest['files'].items():
        path = HERE / 'generated' / name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
        if path.suffix == '.sql':
            check_sql_lexical(path.read_text())
    bootstrap = (HERE / 'generated/bootstrap-synthetic.sql').read_text()
    role_start = bootstrap.index('SET ROLE postgres;')
    for token in ('CREATE ROLE anon', 'CREATE ROLE authenticated', 'CREATE ROLE service_role',
                  'GRANT USAGE,CREATE ON SCHEMA public TO postgres;'):
        assert bootstrap.index(token) < role_start, token
    fixture = json.loads((HERE / 'generated/fixtures-synthetic.json').read_text())
    apply = (HERE / 'generated/apply-synthetic.sql').read_text()
    rollback = (HERE / 'generated/rollback-synthetic.sql').read_text()
    for sql in (apply, rollback):
        assert sql.count('DO $migration$') == 1
        assert sql.count("RAISE EXCEPTION 'private table metadata changed'") == 2
        assert sql.count('SET epoch=epoch+1') == 1
        assert sql.count('EXECUTE $definition$') == 1
        assert sql.count('::oid') == 8
        assert len(re.findall(r"\b(?:BEGIN|END)\b", sql)) > 0
        assert 'SYNTHETIC_TABLE_ACL' in sql
        assert 'SYNTHETIC-EVIDENCE-NOT-A-REAL-DOCUMENT' in sql
    assert '(e.source_table,e.source_ref) IS DISTINCT FROM' in apply
    assert apply.count('INTO unrelated_before') == 1
    assert apply.count('INTO unrelated_after') == 1
    assert 'another contract adopted policy' in rollback
    for name, body in [('apply-synthetic.sql', 'guard-candidate-synthetic.sql'),
                       ('rollback-synthetic.sql', 'guard-original-synthetic.sql')]:
        text = (HERE / 'generated' / name).read_text()
        guard = (HERE / 'generated' / body).read_text()
        assert guard in text, 'Exact definition was not preserved'
    before = apply.split('EXECUTE $definition$', 1)[0]
    assert before.index('RETURN;') < before.index('contract or guard lease changed')
    assert 'INTO unrelated_after' not in before
    assert 'SET epoch=epoch+1' not in before
    after = apply.split('$definition$;', 1)[1]
    tokens = ['UPDATE public.lts_card_settlement_expense_contract_v273',
              'installed definition mismatch', 'scoped final consumer mismatch',
              'unrelated rows changed', 'documentary evidence changed',
              'private table metadata changed', 'SET epoch=epoch+1']
    indexes = [after.index(t) for t in tokens]
    assert indexes == sorted(indexes)
    allowed_uuids = {
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '99999999-9999-4999-8999-999999999999',
        *(f'11111111-1111-4111-8111-{i:012d}' for i in (1, 2, 3)),
    }
    for name in files:
        content = (HERE / name).read_text()
        found = set(re.findall(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', content, re.I))
        assert found <= allowed_uuids, 'Non-fixture UUID in ' + name
    # No opt-in means the runtime runner exits before any psql process can be launched.
    refusal = subprocess.run([sys.executable, str(HERE / 'run_envelope_postgres17.py')],
                             capture_output=True, text=True)
    assert refusal.returncode == 2
    assert 'no database was contacted' in refusal.stderr
    print(json.dumps({'status': 'static-passed', 'sql_execution': False,
                      'postgresql_parser_used': False,
                      'scope': ['Python AST', 'SQL delimiter and parentheses balance',
                                'artifact hashes', 'envelope ordering', 'synthetic UUID allowlist',
                                'runner refuses without opt-in'],
                      'source_builder_sha256': manifest['source_builder_sha256']}, indent=2))


if __name__ == '__main__':
    main()
