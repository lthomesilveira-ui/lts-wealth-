#!/usr/bin/env python3
"""Generate only local, synthetic pg_temp tests. Does not connect to a database."""
import argparse
import copy
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FUNCTION = 'lts_card_settlement_evidence_valid_v273'
POLICY = 'raw_except_updatedAt_v1'
U2 = '44444444-4444-4444-8444-444444444444'
SOURCE_HASHES = {
    'pure-tests.sql': '66931799f7e2c621eb2cddb8162be5937876e7271d1bcdf5bc4a4345489b44ba',
    'fixtures.json': 'f478234e63b698e45b27c28e6d1677ad82b5ed885c8466344ae5319d14d24165',
    'pure-guard.sql': '583482ad32d5fba639c3165bdbffe954980ae705c8a2e6d1e458ffc63bc841a9',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def json_literal(value):
    return literal(json.dumps(value, ensure_ascii=False, separators=(',', ':'))) + '::jsonb'


def function_body(path, target):
    source = path.read_text()
    match = re.fullmatch(r'(CREATE OR REPLACE FUNCTION public\.' + FUNCTION +
                         r'\(.*?\$guard\$;)(?:\s*REVOKE ALL.*)?\s*', source, re.S)
    assert match, f'Unexpected function wrapper: {path}'
    body = match[1].replace('public.' + FUNCTION, 'pg_temp.' + target, 1)
    assert 'LANGUAGE sql IMMUTABLE SET search_path TO \'\'' in body
    assert not re.search(r'\b(?:INSERT|UPDATE|DELETE|TRUNCATE|ALTER|DROP|COPY|CALL|DO|EXECUTE)\b', body, re.I)
    assert 'public.' not in body, 'Pure test function must have no public-schema dependency'
    return body


def parse_inherited():
    sql = (HERE / 'inputs/pure-tests.sql').read_text()
    rows = re.findall(r"SELECT '([^']+)' test,pg_temp\." + FUNCTION +
                      r'\((.*?)\) actual,(true|false) expected', sql, re.S)
    result = []
    for name, args, expected in rows:
        fields = re.findall(r"'((?:''|[^'])*)'::(uuid|date|jsonb)", args)
        assert len(fields) == 9, (name, len(fields))
        vals = [json.loads(v.replace("''", "'")) if kind == 'jsonb' else v.replace("''", "'")
                for v, kind in fields]
        result.append((name, vals, expected == 'true'))
    assert len(result) == 75
    return result


def canonical_raw(issuer):
    # Every identity/value here is invented. Include fields the guard does not know about.
    return {
        'id': 'synthetic-bill', 'dueDate': '2026-10-12', 'closingDate': '2026-10-05',
        'currencyCode': 'BRL', 'totalAmount': 100, 'minimumPaymentAmount': 15,
        'status': 'CLOSED', 'payments': copy.deepcopy(issuer),
        'fees': [{'type': 'ANNUITY', 'amount': 0}, {'type': 'INTEREST', 'amount': 0}],
        'providerExtension': {'unknownFlag': True, 'nullable': None,
                              'updatedAt': 'nested-value-must-not-be-ignored',
                              'nested': {'tags': ['alpha', 'beta'], 'version': 7}},
        'updatedAt': '2026-10-15T12:00:00.000Z',
    }


def upgrade(args, reference):
    args = copy.deepcopy(args)
    if isinstance(args[3], dict):
        raw = copy.deepcopy(reference)
        raw.update(args[3].get('raw_payload', {}))
        args[3]['raw_payload'] = raw
    if isinstance(args[7], dict):
        args[7]['invoice_evidence_policy'] = POLICY
        args[7]['invoice_canonical_payload'] = {k: copy.deepcopy(v) for k, v in reference.items()
                                                  if k != 'updatedAt'}
    return args


def manifest(item):
    return {'id': item['id'], 'raw_hash': item['raw_hash'], 'signed_amount': item['signed_amount'],
            'status': item['normalized_payload']['status'], 'raw_status': item['raw_payload']['status'],
            'operation_type': item['raw_payload']['operationType']}


def freeze_items(args):
    contract = args[7]
    contract['manifest'] = sorted([manifest(i) for i in args[5]], key=lambda i: i['id'])
    contract['consumption_manifest'] = [m for m in contract['manifest'] if m['operation_type'] != 'PAGAMENTO_FATURA']
    contract['settlement_manifest'] = [m for m in contract['manifest'] if m['operation_type'] == 'PAGAMENTO_FATURA']
    args[8] = [dict(source_ref=m['id'], amount=-m['signed_amount'],
                   competence_month=contract['competence_month'], coverage_mode=contract['coverage_mode'])
               for m in contract['consumption_manifest']]


def resize_62(args, refund=False):
    args = copy.deepcopy(args)
    template = copy.deepcopy(args[5][0])
    items = []
    for index in range(62):
        item = copy.deepcopy(template)
        item.update(id=f'synthetic-consumption-{index + 1:03}', raw_hash=f'synthetic-item-hash-{index + 1:03}', signed_amount=-20)
        if refund and index == 61:
            item['signed_amount'] = 20
            item['raw_payload']['operationType'] = 'ESTORNO'
        items.append(item)
    amount = -sum(i['signed_amount'] for i in items)
    settlement = copy.deepcopy(args[5][-1])
    settlement.update(id='synthetic-settlement-063', raw_hash='synthetic-settlement-hash-063', signed_amount=amount)
    items.append(settlement)
    args[5] = items
    args[2]['expected_amount'] = args[3]['signed_amount'] = args[7]['amount'] = amount
    args[4]['signed_amount'] = -amount
    args[3]['raw_payload']['totalAmount'] = amount
    args[3]['raw_payload']['payments'][0]['amount'] = amount
    args[7]['issuer_payments'] = copy.deepcopy(args[3]['raw_payload']['payments'])
    args[7]['link_contract'] = copy.deepcopy(args[2])
    args[7]['invoice_canonical_payload'] = {k: copy.deepcopy(v) for k, v in args[3]['raw_payload'].items() if k != 'updatedAt'}
    freeze_items(args)
    assert len(args[5]) == 63 and len(args[8]) == 62
    return args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, default=ROOT / 'candidate-pure-guard.sql')
    parser.add_argument('--out', type=Path, default=HERE / 'generated')
    opts = parser.parse_args()
    for name, expected in SOURCE_HASHES.items():
        assert digest(HERE / 'inputs' / name) == expected, f'Synthetic V3 input changed: {name}'
    inherited = parse_inherited()
    fixture = json.loads((HERE / 'inputs/fixtures.json').read_text())
    base = fixture['base'] + [fixture['contract'], fixture['coverage']]
    assert base == inherited[0][1]
    raw = canonical_raw(base[7]['issuer_payments'])
    modern = upgrade(base, raw)
    rows = []

    def add(name, args, expected, group, guard='candidate'):
        rows.append(dict(name=name, group=group, guard=guard, args=copy.deepcopy(args), expected=expected))

    for name, args, expected in inherited:
        for guard in ('baseline', 'candidate'):
            add('legacy_' + name, args, expected, 'legacy-exact', guard)
        # Only the invoice hash is deliberately relaxed by the explicit new policy.
        add('policy_' + name, upgrade(args, raw), True if name == 'invoice_hash_changed' else expected,
            'policy-inherited-invariants')

    add('new_policy_valid', modern, True, 'timestamp')
    timestamp = copy.deepcopy(modern)
    timestamp[3]['raw_payload']['updatedAt'] = '2026-10-16T13:59:59.123456Z'
    timestamp[3]['raw_hash'] = 'synthetic-refreshed-invoice-hash'
    add('timestamp_only_old_guard_rejects', timestamp, False, 'negative-control', 'baseline')
    add('timestamp_only_new_guard_accepts', timestamp, True, 'negative-control')
    legacy_timestamp = copy.deepcopy(timestamp)
    del legacy_timestamp[7]['invoice_evidence_policy']
    del legacy_timestamp[7]['invoice_canonical_payload']
    add('timestamp_only_legacy_contract_still_rejects', legacy_timestamp, False, 'legacy-policy-boundary')
    for value in ('2027-01-01T00:00:00Z', '2026-01-01T00:00:00.1Z'):
        a = copy.deepcopy(timestamp); a[3]['raw_payload']['updatedAt'] = value
        add('timestamp_only_' + value, a, True, 'timestamp')
    for value in (None, {}, [], 123, True, '', '2026-10-16', '2026-10-16T13:00:00+00:00', '2026-10-16T13:00:00z', 'wrong'):
        a = copy.deepcopy(modern); a[3]['raw_payload']['updatedAt'] = value
        add('bad_timestamp_' + json.dumps(value), a, False, 'timestamp-shape')
    a = copy.deepcopy(modern); del a[3]['raw_payload']['updatedAt']
    add('missing_updatedAt', a, False, 'timestamp-shape')
    for value in ('unknown', '', 1, {}, [], False):
        a = copy.deepcopy(modern); a[7]['invoice_evidence_policy'] = value
        add('unknown_policy_' + json.dumps(value), a, False, 'policy-boundary')
    for value in (None, [], 'text', 42):
        a = copy.deepcopy(modern); a[7]['invoice_canonical_payload'] = value
        add('bad_canonical_' + json.dumps(value), a, False, 'policy-boundary')
    a = copy.deepcopy(modern); del a[7]['invoice_canonical_payload']
    add('missing_canonical', a, False, 'policy-boundary')
    a = copy.deepcopy(modern); a[7]['invoice_canonical_payload']['updatedAt'] = 'not-excluded'
    add('canonical_accidentally_contains_updatedAt', a, False, 'policy-boundary')
    for value in (None, [], 'text', 42):
        a = copy.deepcopy(modern); a[3]['raw_payload'] = value
        add('bad_raw_payload_' + json.dumps(value), a, False, 'policy-boundary')

    # Mutate/remove every reachable field, including containers and unknown nested fields.
    # Both unchanged and changed raw hashes must reject: new policy must not fall back to hash.
    paths = []
    def visit(value, path=()):
        if path:
            paths.append(path)
        if isinstance(value, dict):
            for key, child in value.items():
                if not path and key == 'updatedAt':
                    continue
                visit(child, path + (key,))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, path + (index,))
    visit(raw)
    for path in paths:
        for action in ('replace', 'remove'):
            for changed_hash in (False, True):
                a = copy.deepcopy(modern)
                target = a[3]['raw_payload']
                for key in path[:-1]: target = target[key]
                if action == 'replace': target[path[-1]] = {'syntheticChangedValue': 'different'}
                else: del target[path[-1]]
                if changed_hash: a[3]['raw_hash'] = 'synthetic-refreshed-invoice-hash'
                add(f'raw_{action}_{json.dumps(path)}_hash_changed_{changed_hash}', a, False, 'all-raw-field-mutations')
    for path in ((), ('providerExtension',), ('providerExtension', 'nested'), ('payments', 0)):
        a = copy.deepcopy(modern); target = a[3]['raw_payload']
        for key in path: target = target[key]
        target['neverSeenProviderField'] = {'nested': [1, 2, {'changed': True}]}
        add('unknown_addition_' + json.dumps(path), a, False, 'unknown-additions')
    a = copy.deepcopy(modern); a[3]['raw_payload']['fees'].reverse()
    add('raw_array_order_changed', a, False, 'array-identity')
    a = copy.deepcopy(modern)
    a[3]['raw_payload'] = dict(reversed(list(a[3]['raw_payload'].items())))
    add('json_object_key_order_irrelevant', a, True, 'json-semantics')

    # Two distinct issuer payments preserve sum but make ordering/duplication observable.
    two_payments = copy.deepcopy(modern)
    first = two_payments[3]['raw_payload']['payments'][0]
    first['amount'] = 60
    second = copy.deepcopy(first); second.update(id='synthetic-issuer-second', amount=40)
    two_payments[3]['raw_payload']['payments'].append(second)
    two_payments[7]['issuer_payments'] = copy.deepcopy(two_payments[3]['raw_payload']['payments'])
    two_payments[7]['invoice_canonical_payload']['payments'] = copy.deepcopy(two_payments[3]['raw_payload']['payments'])
    add('two_issuer_payments_valid', two_payments, True, 'issuer-payments-exact')
    a = copy.deepcopy(two_payments); a[3]['raw_payload']['payments'].reverse()
    add('issuer_payments_order_changed', a, False, 'issuer-payments-exact')
    a = copy.deepcopy(two_payments); a[3]['raw_payload']['payments'].append(copy.deepcopy(a[3]['raw_payload']['payments'][0]))
    add('issuer_payments_duplicated', a, False, 'issuer-payments-exact')
    a = copy.deepcopy(two_payments); a[3]['raw_payload']['payments'][0]['id'] = 'synthetic-other-payment-id'
    add('issuer_payments_identity_changed_same_sum', a, False, 'issuer-payments-exact')

    for refunded in (False, True):
        many = resize_62(modern, refunded)
        suffix = '_with_refund' if refunded else ''
        add('consumptions62_settlement63' + suffix, many, True, '62-plus-settlement')
        a = copy.deepcopy(many); a[3]['raw_payload']['updatedAt'] = '2026-10-16T14:00:00Z'; a[3]['raw_hash'] = 'hash-after-refresh'
        add('consumptions62_timestamp_only' + suffix, a, True, '62-plus-settlement')
        mutations = [
            ('coverage_missing', lambda a: a[8].pop()),
            ('coverage_duplicate', lambda a: a[8].append(copy.deepcopy(a[8][0]))),
            ('coverage_settlement_included', lambda a: a[8].append(dict(source_ref=a[5][-1]['id'], amount=-a[5][-1]['signed_amount'], competence_month='2026-10-01', coverage_mode='card_bank_closed_complete'))),
            ('item_missing', lambda a: a[5].pop(0)),
            ('settlement_missing', lambda a: a[5].pop()),
            ('settlement_duplicate', lambda a: a[5].append(copy.deepcopy(a[5][-1]))),
            ('item_duplicate', lambda a: a[5].append(copy.deepcopy(a[5][0]))),
            ('same_amount_different_identity', lambda a: a[5][0].update(id='synthetic-replacement-id')),
            ('item_wrong_owner', lambda a: a[5][0].update(user_id=U2)),
            ('payment_partial', lambda a: a[4].update(signed_amount=-10)),
            ('payment_reversed', lambda a: a[4].update(signed_amount=abs(a[4]['signed_amount']))),
            ('settlement_partial', lambda a: a[5][-1].update(signed_amount=10)),
            ('contract_revoked', lambda a: a[7].update(active=False)),
            ('link_revoked', lambda a: a[2].update(active=False)),
        ]
        for name, change in mutations:
            a = copy.deepcopy(many); change(a)
            add('consumptions62_' + name + suffix, a, False, '62-plus-settlement')
        a = copy.deepcopy(many); a[5].reverse(); a[8].reverse()
        add('consumptions62_input_order_irrelevant' + suffix, a, True, '62-plus-settlement')
        # Coherent duplicate inputs/contracts still cannot bypass uniqueness.
        a = copy.deepcopy(many); a[5].append(copy.deepcopy(a[5][0])); freeze_items(a)
        add('consumptions62_duplicate_in_frozen_manifest' + suffix, a, False, '62-plus-settlement')

    assert len({(r['guard'], r['name']) for r in rows}) == len(rows)
    opts.out.mkdir(parents=True, exist_ok=True)
    fixture_path = opts.out / 'synthetic-cases.json'
    fixture_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    sql = """\\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';
SET LOCAL lock_timeout='2s';
DO $boundary$ BEGIN
 IF current_setting('server_version_num')::integer / 10000 <> 17 THEN RAISE EXCEPTION 'PostgreSQL17 required'; END IF;
 IF current_database() <> 'lts_p05_synthetic' OR current_user <> 'lts_p05_synthetic' THEN RAISE EXCEPTION 'Synthetic-only database/user required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema' AND c.relkind IN ('r','p','v','m','f')) THEN RAISE EXCEPTION 'Expected a fresh empty synthetic database'; END IF;
END $boundary$;
"""
    sql += function_body(HERE / 'inputs/pure-guard.sql', 'p05_baseline') + '\n'
    sql += function_body(opts.candidate, 'p05_candidate') + '\n'
    sql += "CREATE TEMP TABLE p05_results(test text, test_group text, guard text, expected boolean, actual boolean, error text) ON COMMIT DROP;\n"
    # Per-case exception capture reports errors as failures, never as a passing fail-closed result.
    sql += "CREATE TEMP TABLE p05_cases (payload jsonb) ON COMMIT DROP;\n"
    for row in rows:
        sql += 'INSERT INTO p05_cases VALUES (' + json_literal(row) + ');\n'
    sql += r"""
DO $run$
DECLARE c jsonb; a jsonb; actual boolean; err text;
BEGIN
 FOR c IN SELECT payload FROM p05_cases LOOP
  a := c->'args'; actual := NULL; err := NULL;
  BEGIN
   IF c->>'guard'='baseline' THEN
    actual := pg_temp.p05_baseline((a->>0)::uuid,(a->>1)::uuid,a->2,a->3,a->4,a->5,(a->>6)::date,a->7,a->8);
   ELSE
    actual := pg_temp.p05_candidate((a->>0)::uuid,(a->>1)::uuid,a->2,a->3,a->4,a->5,(a->>6)::date,a->7,a->8);
   END IF;
  EXCEPTION WHEN OTHERS THEN err := SQLSTATE || ': ' || SQLERRM;
  END;
  INSERT INTO p05_results VALUES(c->>'name',c->>'group',c->>'guard',(c->>'expected')::boolean,actual,err);
 END LOOP;
END $run$;
SELECT jsonb_build_object('server_version',current_setting('server_version'),'synthetic_only',true,'tests',count(*),'passed',count(*) FILTER(WHERE error IS NULL AND actual IS NOT DISTINCT FROM expected),'groups',(SELECT jsonb_object_agg(test_group,n) FROM (SELECT test_group,count(*) n FROM p05_results GROUP BY test_group)g),'failures',coalesce(jsonb_agg(to_jsonb(p05_results)) FILTER(WHERE error IS NOT NULL OR actual IS DISTINCT FROM expected),'[]'::jsonb)) FROM p05_results;
DO $assert$ BEGIN
 IF EXISTS(SELECT 1 FROM p05_results WHERE error IS NOT NULL OR actual IS DISTINCT FROM expected) THEN RAISE EXCEPTION 'P05 synthetic regression failed; inspect result JSON above'; END IF;
END $assert$;
ROLLBACK;
"""
    (opts.out / 'synthetic-gate.sql').write_text(sql)
    summary = dict(synthetic_only=True, case_count=len(rows), inherited_exact_case_count=75,
                   groups=dict(Counter(r['group'] for r in rows)),
                   source_sha256=SOURCE_HASHES, candidate_sha256=digest(opts.candidate),
                   generated_sha256={name: digest(opts.out / name) for name in ('synthetic-gate.sql', 'synthetic-cases.json')},
                   limitations=['Pure JSONB guard only; no deployed wrapper, ledger, RPC, RLS or production data is executed.',
                                'Build/static checks do not establish SQL outcomes; run in fresh PostgreSQL17 service.'])
    (opts.out / 'manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
