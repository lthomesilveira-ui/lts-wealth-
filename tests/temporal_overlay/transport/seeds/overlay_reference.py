"""Pure synthetic reference. No adapter, I/O, dates inferred from due or live sources."""
from collections import defaultdict
from copy import deepcopy
from datetime import date, datetime, timezone
from decimal import Decimal
import re, json

VERSION = 'temporal_date_overlay_pg17_v1'
KEYS = ('owner', 'institution', 'account', 'bill_id')
METHODS = {'existing_bill_binding', 'explicit_issuer_cycle', 'linked_transaction_cycle_independent_of_due'}
CHANGING = {'due', 'provenance', 'source_updated', 'bill_key', 'due_basis'}

def identity(value):
    return isinstance(value, str) and re.fullmatch(r'[!-~]+', value) is not None

def key(row):
    return {k: row.get(k) for k in KEYS}

def key_tuple(row):
    return tuple(row.get(k) for k in KEYS)

def valid_key(row):
    return isinstance(row, dict) and all(identity(row.get(k)) for k in KEYS)

def day(s):
    if not isinstance(s, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', s):
        return None
    try:
        return date.fromisoformat(s)
    except ValueError:
        return None

def stamp(s):
    if not isinstance(s, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,6})?(?:Z|[+-][0-9]{2}:[0-9]{2})', s):
        return None
    try:
        # Explicit offset limit prevents Python normalizing malformed +01:60.
        if not s.endswith('Z') and (int(s[-5:-3]) > 14 or int(s[-2:]) > 59 or (int(s[-5:-3]) == 14 and int(s[-2:]) != 0)):
            return None
        dt = datetime.fromisoformat(s.replace('Z', '+00:00'))
        return dt.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        return None

def money(s):
    return Decimal(s) if isinstance(s, str) and re.fullmatch(r'[0-9]{1,18}(?:\.[0-9]{1,2})?', s) else None

def id_array(value):
    return isinstance(value, list) and all(identity(x) for x in value)

def validate(p):
    if not isinstance(p, dict) or any(not isinstance(p.get(k), list) for k in ('obligations', 'bills', 'bindings')):
        return 'invalid_envelope'
    if not day(p.get('today')) or not day(p.get('protected_through')) or day(p['protected_through']).day != 1:
        return 'invalid_envelope'
    events = []
    for o in p['obligations']:
        if (not isinstance(o, dict) or any(not identity(o.get(k)) for k in ('event_id', 'owner', 'institution', 'account', 'family', 'cycle_id'))
            or not day(o.get('reference_month')) or day(o['reference_month']).day != 1
            or (o.get('due') is not None and not day(o['due'])) or money(o.get('amount')) is None
            or not id_array(o.get('payment_ids')) or not id_array(o.get('purchase_ids'))
            or (o.get('bill_key') is not None and not valid_key(o['bill_key']))):
            return 'invalid_obligation_input'
        events.append(o['event_id'])
    if len(set(events)) != len(events):
        return 'duplicate_event_id'
    if any(not valid_key(b) for b in p['bills']):
        return 'invalid_source_identity'
    for b in p['bindings']:
        if (not valid_key(b) or any(not identity(b.get(k)) for k in ('event_id', 'cycle_id', 'method'))
            or not day(b.get('reference_month')) or day(b['reference_month']).day != 1):
            return 'invalid_binding_input'
    return None

def json_token(value):
    """Hashable JSONB-like equality: booleans differ from numbers; numbers exact."""
    if value is None: return ('null',)
    if type(value) is bool: return ('boolean',value)
    if type(value) in (int,float,Decimal): return ('number',Decimal(str(value)))
    if isinstance(value,str): return ('string',value)
    if isinstance(value,list): return ('array',tuple(json_token(x) for x in value))
    if isinstance(value,dict): return ('object',tuple((k,json_token(v)) for k,v in sorted(value.items())))
    raise ValueError('not a JSON value')

def result(p):
    reason = validate(p)
    original = deepcopy(p.get('obligations', [])) if isinstance(p,dict) else []
    if reason:
        return {'version': VERSION, 'batch_state': reason, 'obligations': original, 'decisions': [], 'source_findings': []}
    groups, heads, findings = defaultdict(list), {}, []
    for b in p['bills']:
        groups[key_tuple(b)].append(b)
    for k in sorted(groups):
        versions = groups[k]
        if any(stamp(b.get('source_updated')) is None for b in versions):
            code = 'unknown_source_recency'
        else:
            latest = max(stamp(b['source_updated']) for b in versions)
            top = [b for b in versions if stamp(b['source_updated']) == latest]
            def signature(b):
                return json_token([b.get('family'), b.get('due'), b.get('amount'), b.get('closing_date'), b.get('deleted')])
            # Schema is deliberately strict: monetary strings are canonical source values.
            if any(type(b.get('deleted')) is not bool for b in top):
                code = 'unknown_source_state'
            elif len({signature(b) for b in top}) != 1:
                code = 'conflicting_latest_revision'
            elif top[0]['deleted']:
                code = 'latest_source_deleted_preserved'
            else:
                winner = min(top, key=lambda b: b['source_updated'])
                if (not identity(winner.get('family')) or money(winner.get('amount')) is None
                    or (winner.get('closing_date') is not None and day(winner['closing_date']) is None)):
                    code = 'invalid_source_fields'
                else:
                    heads[k] = winner
                    code = None
        if code:
            findings.append({'key': key(versions[0]), 'code': code})
    links = defaultdict(list)
    for b in p['bindings']:
        if all(json_token(b)!=json_token(old) for old in links[key_tuple(b)]):
            links[key_tuple(b)].append(b)
    events = {o['event_id']: o for o in p['obligations']}
    candidates, claims = defaultdict(list), defaultdict(set)
    for k, ls in links.items():
        for l in ls:
            o = events.get(l['event_id'])
            if (o and l['method'] in METHODS and l['cycle_id'] == o['cycle_id'] and l['reference_month'] == o['reference_month']
                and all(l[x] == o[x] for x in ('owner', 'institution', 'account'))):
                claims[o['event_id']].add(k)
    for k in sorted(heads):
        b = heads[k]; ls = links[k]
        if len(ls) != 1:
            code = 'missing_or_ambiguous_cycle_binding'
        else:
            l = ls[0]; o = events.get(l['event_id'])
            if (not o or l['method'] not in METHODS or l['cycle_id'] != o['cycle_id'] or l['reference_month'] != o['reference_month']
                or any(b[x] != o[x] for x in ('owner', 'institution', 'account', 'family'))
                or (o.get('bill_key') is not None and key_tuple(o['bill_key']) != k)):
                code = 'binding_identity_mismatch'
            else:
                candidates[o['event_id']].append(b); code = None
        if code:
            findings.append({'key': key(b), 'code': code})
    output, decisions = [], []
    for o in p['obligations']:
        bs = candidates[o['event_id']]; b = bs[0] if len(bs) == 1 else None
        if day(o['reference_month']) <= day(p['protected_through']):
            code = 'protected_cycle_preserved'
        elif o.get('status') not in ('open', 'projected') or o['payment_ids']:
            code = 'fulfilled_or_unknown_status_preserved'
        elif len(claims[o['event_id']]) > 1:
            code = 'multiple_bills_for_one_obligation'
        elif b is None:
            code = 'no_eligible_invoice'
        elif day(b.get('due')) is None:
            code = 'missing_or_invalid_invoice_due'
        elif money(b['amount']) != money(o['amount']):
            code = 'amount_change_outside_date_only_scope'
        elif o.get('provenance') == 'issuer_invoice':
            if stamp(o.get('source_updated')) is None:
                code = 'unknown_snapshot_recency'
            elif o.get('bill_key') is None:
                code = 'missing_snapshot_bill_identity'
            elif stamp(b['source_updated']) < stamp(o['source_updated']):
                code = 'older_issuer_revision_preserved'
            elif stamp(b['source_updated']) == stamp(o['source_updated']) and b['due'] != o.get('due'):
                code = 'equal_revision_conflict'
            else:
                code = 'overlay_applied'
        elif o.get('provenance') != 'estimate':
            code = 'documentary_conflict_requires_reconciliation'
        else:
            code = 'overlay_applied'
        after = deepcopy(o)
        if code == 'overlay_applied':
            after.update(due=b['due'], provenance='issuer_invoice', source_updated=b['source_updated'], bill_key=key(b), due_basis='issuer_exact_cycle')
        output.append(after)
        decisions.append({'event_id': o['event_id'], 'code': code, 'changed_due': after.get('due') != o.get('due')})
    # Stable previous identity missing from the entire input snapshot is not deletion.
    for o in p['obligations']:
        if o.get('bill_key') is not None and key_tuple(o['bill_key']) not in groups:
            findings.append({'key': key(o['bill_key']), 'code': 'previous_source_missing_preserved'})
    findings = sorted({(key_tuple(f['key']), f['code']) for f in findings})
    return {'version': VERSION, 'batch_state': 'valid', 'obligations': output, 'decisions': decisions,
            'source_findings': [{'key': dict(zip(KEYS, k)), 'code': c} for k, c in findings]}
