"""Resolve explicit own-bank transfer rows against an unchanged original workbook.

Input files and output contain private data and must stay outside the repository.
No amount/date-only pairing, source mutation, or inferred beneficiary is performed.
"""
import argparse
from collections import defaultdict, Counter
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
import json
import re
import unicodedata


def normalized(value):
    return re.sub(r"\s+", " ", str(value).strip().casefold())


def cents(value):
    original = Decimal(str(value))
    rounded = original.quantize(Decimal('0.01'))
    if abs(original-rounded) > Decimal('0.000000001'):
        raise ValueError('Document has a substantive sub-cent amount')
    return rounded


def resolve(workbook, source, effective):
    indexed = defaultdict(list)
    for row in workbook['ledger_rows']:
        i = str(row['row'])
        c = row['cells']
        if c.get('G'+i) != 'Transferência Bancária':
            continue
        try:
            day = (date(1899, 12, 30) + timedelta(days=int(Decimal(c['C'+i])))).isoformat()
            amount = cents(c['B'+i])
            description = c['A'+i]
        except (KeyError, ValueError, ArithmeticError, TypeError):
            continue
        indexed[(normalized(description), day, abs(amount))].append({
            'row': row['row'], 'amount': str(amount),
            'cells': {k+i: c[k+i] for k in ['A', 'B', 'C', 'G']},
        })
    rows = {x['source_ref']: x for x in effective}
    matched, rejected = [], []
    for raw in source:
        payload, idx = raw['dados'], raw['idx']
        desc, day = payload.get('desc', ''), payload.get('dia', '')
        amount = cents(payload['valor'])
        candidates = indexed.get((normalized(desc), day, abs(amount)), [])
        reason = None
        if day > '2026-07-31' or len(candidates) != 1:
            reason = 'outside_source_period_or_nonunique_original_row'
        elif Decimal(candidates[0]['amount']) <= 0:
            # The sheet records magnitudes. An exceptional negative value is a
            # reversal/conflict to investigate, never silently normalised.
            reason = 'original_signed_exception'
        plain = ''.join(c for c in unicodedata.normalize('NFKD', normalized(desc))
                        if not unicodedata.combining(c))
        banks = re.findall(r'itau|bradesco|c6', plain)
        names = {'itau': 'Itaú', 'bradesco': 'Bradesco', 'c6': 'C6'}
        if len(banks) != 2 or banks[0] == banks[1]:
            reason = reason or 'explicit_distinct_bank_endpoints_missing'
        incoming = plain.startswith('recebimento ')
        outgoing = plain.startswith(('transferencia ', 'saida '))
        if not (incoming or outgoing) or payload.get('efeito') != ('entrada' if incoming else 'saida'):
            reason = reason or 'explicit_direction_conflict'
        signed = abs(amount) if incoming else -abs(amount)
        actual = rows.get('evento_base:'+str(idx))
        if actual is None:
            reason = reason or 'effective_source_missing'
        if len(banks) == 2:
            origin, destination = names[banks[0]], names[banks[1]]
            account = destination if incoming else origin
            if actual and (actual['account'] != account or
                           Decimal(str(actual['signed_amount'])) != signed or
                           normalized(actual['description']) != normalized(desc)):
                reason = reason or 'effective_identity_conflict'
        if reason:
            rejected.append({'idx': idx, 'reason': reason})
            continue
        matched.append({**raw, 'workbook': candidates[0],
                        'workbook_sha256': workbook['source_sha256'],
                        'origin_bank': origin, 'destination_bank': destination,
                        'signed_amount': str(signed), 'effective_account': account})
    return {'source_sha256': workbook['source_sha256'], 'matched': matched, 'rejected': rejected}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('workbook_json', type=Path)
    parser.add_argument('source_json', type=Path)
    parser.add_argument('effective_json', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = resolve(*(json.loads(p.read_text()) for p in
                       [args.workbook_json, args.source_json, args.effective_json]))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'matched': len(result['matched']), 'rejected': result['rejected'],
                      'directions': dict(Counter('in' if Decimal(x['signed_amount']) > 0 else 'out'
                                                 for x in result['matched'])),
                      'original_amounts_dates_preserved': True}))


if __name__ == '__main__':
    main()
