"""Public, self-contained PostgreSQL 17 regression gate for the identity marker.

Import run_marker(sql_callable). The callable must execute the supplied complete
SQL transaction in the isolated CI database and return psql stdout as a string;
raise on any PostgreSQL/client error. This module opens no database connection,
reads no private baselines, and writes no artifacts.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Callable, Any

HERE = Path(__file__).resolve().parent
EXPECTED_MATRIX_ROWS = 8 * 3 * 5 * 3 * 3 * 12 * 3
EXPECTED_NAMED_ROWS = 13
EXPECTED_CHECKS = {
    'original_matches_oracle',
    'candidate_matches_oracle',
    'sql_null_raw_predicates',
    'nineteen_other_columns_invariant',
    'only_allowed_transitions',
    'never_creates_pending',
    'education_is_invariant',
    'all_unrelated_reasons_preserved',
    'nullable_raw_coverage',
    'named_generic_transitions',
    'loan_subgroup_uses_declared_stub',
    'matched_property_projection_branch',
    'row_cardinality_and_key_set',
}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _read(name: str) -> str:
    return (HERE / name).read_text(encoding='utf-8')


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def verify_public_sources() -> dict[str, Any]:
    """Verify exported provenance and exact local diff; no SQL is executed here."""
    proof = json.loads(_read('source-proof.json'))
    _require(proof['proof_version'] == 1, 'Unsupported marker source proof version')
    expected_names = {
        'projection-original.sql', 'projection-candidate.sql',
        'identity-original.sql', 'identity-candidate.sql',
        'p05-original.sql', 'p05-candidate.sql', 'return-columns.sql',
    }
    _require(set(proof['artifact_sha256']) == expected_names, 'Unexpected marker artifact list')
    for name in sorted(expected_names):
        _require(_sha(_read(name)) == proof['artifact_sha256'][name], f'Marker artifact hash mismatch: {name}')
    old = proof['old_expression']
    new = proof['new_expression']
    _require(old == "(kind in ('Saúde','Educação','Vestuário') and person_final is null)", 'Unexpected old marker expression')
    _require(new == "(kind='Educação' and person_final is null)", 'Unexpected candidate marker expression')
    for family in ('projection', 'identity'):
        a = _read(f'{family}-original.sql')
        b = _read(f'{family}-candidate.sql')
        _require(a.count(old) == b.count(new) == 1, f'Unexpected {family} marker multiplicity')
        _require(a.replace(old, new) == b, f'Unexpected change outside {family} marker')
    _require(_read('p05-original.sql') == _read('p05-candidate.sql'), 'P05 block changed')
    _require(_sha(_read('p05-original.sql')) == proof['p05_block_sha256'], 'P05 proof hash mismatch')
    for version in ('original', 'candidate'):
        projection = _read(f'projection-{version}.sql')
        identity = _read(f'identity-{version}.sql').strip()
        _require(identity in projection, 'Identity expression not found byte-exact in final projection')
        _require(projection.startswith('select source_table||'), 'Unexpected final projection start')
        _require(projection.endswith('\nfrom labeled\n'), 'Unexpected final projection end')
        _require(projection.count('public.lts_expense_management_subgroup_v2') == 1, 'Unexpected subgroup dependency count')
        _require('public.' not in projection.replace('public.lts_expense_management_subgroup_v2', ''), 'Unexpected schema dependency')
        _require(projection.count("'synthetic-property-matched'") == 2, 'Unexpected synthetic property substitutions')
        _require(projection.count("'Synthetic property display'") == 1, 'Unexpected property display substitution')
    columns = _read('return-columns.sql').strip()
    _require(len(columns.split(',')) == 20, 'Unexpected projection result column count')
    _require('identity_status text' in columns, 'Identity output column missing')
    return {
        'public_artifact_hashes_verified': True,
        'exported_projection_diff_exact': True,
        'identity_expression_byte_exact': True,
        'p05_exported_block_byte_identical': True,
        'private_baseline_diff_verified_at_authoring': proof['baseline_diff_is_exact_single_marker_replacement'],
        'original_baseline_sha256': proof['original_baseline_sha256'],
        'candidate_baseline_sha256': proof['candidate_baseline_sha256'],
        'p05_block_sha256': proof['p05_block_sha256'],
        'private_source_read_by_public_runner': False,
    }


def _raw_predicate(version: str) -> str:
    expression = _read(f'identity-{version}.sql').strip()
    prefix = 'case when '
    suffix = " then 'pending' else 'identified' end"
    _require(expression.startswith(prefix) and expression.endswith(suffix), 'Unexpected identity CASE envelope')
    return expression[len(prefix):-len(suffix)]


def build_marker_sql() -> str:
    """Render a fully synthetic transaction solely from allowlisted public files."""
    verify_public_sources()
    sql = _read('marker-gate.sql')
    replacements = {
        '__RETURN_COLUMNS__': _read('return-columns.sql').strip(),
        '__ORIGINAL_FINAL_PROJECTION__': _read('projection-original.sql').strip(),
        '__CANDIDATE_FINAL_PROJECTION__': _read('projection-candidate.sql').strip(),
        '__ORIGINAL_RAW_PREDICATE__': _raw_predicate('original'),
        '__CANDIDATE_RAW_PREDICATE__': _raw_predicate('candidate'),
    }
    for token, value in replacements.items():
        expected = 2 if token == '__RETURN_COLUMNS__' else 1
        _require(sql.count(token) == expected, f'Unexpected template token multiplicity: {token}')
        sql = sql.replace(token, value)
    _require('__' not in sql, 'Unresolved marker template token')
    _require(sql.rstrip().endswith('ROLLBACK;'), 'Synthetic marker gate must roll back')
    return sql


def run_marker(sql_callable: Callable[[str], str]) -> dict[str, Any]:
    """Run real SQL projections and predicates in the caller's disposable PG17.

    sql_callable must use ON_ERROR_STOP=1 and must raise if psql exits nonzero.
    It must target wealth_synthetic_classifications on isolated loopback CI.
    The SQL itself also checks PostgreSQL 17, database name, and absence of the
    stub dependency before creating anything. The final transaction rolls back.
    """
    provenance = verify_public_sources()
    stdout = sql_callable(build_marker_sql())
    _require(isinstance(stdout, str), 'sql_callable must return PostgreSQL stdout as text')
    results = []
    for line in stdout.splitlines():
        if not line.strip().startswith('{'):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict) and row.get('suite') == 'generic_identity_marker':
            results.append(row)
    _require(len(results) == 1, 'Expected exactly one PostgreSQL marker result object')
    result = results[0]
    _require(170000 <= result.get('server_version_num', 0) < 180000, 'Wrong PostgreSQL version in result')
    _require(result.get('matrix_rows') == EXPECTED_MATRIX_ROWS, 'Marker matrix cardinality mismatch')
    _require(result.get('named_rows') == EXPECTED_NAMED_ROWS, 'Named marker case count mismatch')
    _require(result.get('synthetic_rows') == EXPECTED_MATRIX_ROWS + EXPECTED_NAMED_ROWS, 'Marker total cardinality mismatch')
    checks = result.get('checks', [])
    _require(len(checks) == len(EXPECTED_CHECKS), 'Unexpected number of marker assertions')
    _require({check['test'] for check in checks} == EXPECTED_CHECKS, 'Marker assertion coverage mismatch')
    _require(all(check['passed'] is True and check['checked_rows'] > 0 for check in checks), 'A PostgreSQL marker assertion failed or was vacuous')
    _require(result.get('passed') is True and result.get('failures') == [], 'PostgreSQL marker gate failed')
    _require(result.get('status_changes', 0) >= 2, 'No generic marker transitions exercised')
    _require(result.get('null_original_predicates', 0) > 0 and result.get('null_candidate_predicates', 0) > 0, 'SQL NULL coverage missing')
    result['source_verification'] = provenance
    result['execution_scope'] = 'real_final_projection_with_two_synthetic_property_literals_and_declared_subgroup_stub'
    result['full_baseline_integration_tested'] = False
    result['p05_execution_tested'] = False
    return result
