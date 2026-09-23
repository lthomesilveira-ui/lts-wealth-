"""Bounded, read-only comparison of original daily balances and imported cash.

The JSON input is an explicit complete query window, with one row per account:
{"from":"YYYY-MM-DD","through":"YYYY-MM-DD","accounts":[
  {"account":"Bank","daily":[["YYYY-MM-DD",net,income,outgoing], ...]}
]}
No financial data is written, inferred or patched. The operational boundary is
inclusive: its workbook opening is the historical anchor, never an app override.
"""
import argparse
import datetime as dt
import json
import zipfile
from decimal import Decimal
from audit_original_daily_balances import saved_rows, sheet_member, date, decimal, cents


def reconcile(rows, specs, ledger, boundary, tolerance=2):
    start = dt.date.fromisoformat(ledger['from'])
    through = dt.date.fromisoformat(ledger['through'])
    end = boundary - dt.timedelta(days=1)
    if start > end or through != end:
        raise ValueError('Ledger coverage must end immediately before the protected boundary')
    accounts = {}
    for item in ledger['accounts']:
        if item['account'] in accounts:
            raise ValueError('Duplicate account input')
        daily = {}
        for raw in item['daily']:
            day = dt.date.fromisoformat(raw[0])
            if day in daily or not start <= day <= through:
                raise ValueError('Duplicate or out-of-window daily aggregate')
            net, income, outgoing = map(lambda v: Decimal(str(v)), raw[1:])
            if income < 0 or outgoing < 0 or abs(net-income+outgoing) >= Decimal(tolerance)/100:
                raise ValueError('Invalid gross/net aggregate')
            daily[day] = (net, income, outgoing)
        accounts[item['account']] = daily
    columns = {}
    for col, raw in rows[3].items():
        day = date(raw)
        if day is not None:
            columns.setdefault(day, []).append(col)
    result = {'operational_from': boundary.isoformat(), 'financial_rows_changed': False,
              'expense_history_changed': False, 'accounts': {}}
    for name, opening, income, outgoing, closing, active in specs:
        active = dt.date.fromisoformat(active)
        item = {'compared_days': 0, 'matched_from': None, 'matched_through': None,
                'status': 'not_established', 'stop_reason': None, 'stop_date': None}
        result['accounts'][name] = item
        anchor_columns = columns.get(boundary, [])
        anchor = decimal(rows[opening].get(anchor_columns[0])) if len(anchor_columns) == 1 else None
        if anchor is None or name not in accounts:
            item['stop_reason'] = 'missing_anchor_or_ledger_account'
            continue
        expected_close = anchor
        day = end
        while day >= max(start, active):
            item['stop_date'] = day.isoformat()
            cols = columns.get(day, [])
            if len(cols) != 1:
                item['stop_reason'] = 'missing_or_ambiguous_source_date'
                break
            values = [decimal(rows[row].get(cols[0])) for row in (opening, income, outgoing, closing)]
            if any(value is None for value in values):
                item['stop_reason'] = 'missing_source_balance_or_movement'
                break
            a, inc, out, z = values
            net, ledger_inc, ledger_out = accounts[name].get(day, (Decimal(0),)*3)
            checks = [('source_arithmetic', z-a-inc+out),
                      ('balance_continuity', z-expected_close),
                      ('income_source_difference', ledger_inc-inc),
                      ('outgoing_source_difference', ledger_out-out),
                      ('reverse_balance_difference', z-net-a)]
            failure = next(((reason, delta) for reason, delta in checks if abs(cents(delta)) >= tolerance), None)
            if failure:
                item['stop_reason'], delta = failure
                item['difference_cents'] = cents(delta)
                break
            item['compared_days'] += 1
            item['matched_from'] = day.isoformat()
            item['matched_through'] = end.isoformat()
            expected_close = a
            day -= dt.timedelta(days=1)
        else:
            item['stop_date'] = day.isoformat()
            item['stop_reason'] = 'account_activity_boundary' if active >= start else 'ledger_coverage_boundary'
        if item['compared_days']:
            item['status'] = 'source_compared_candidate'
        # Comparison of current derived cash is evidence, not automatic promotion
        # or transaction-level uniqueness certification in the operational UI.
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workbook')
    parser.add_argument('daily_json')
    parser.add_argument('--bank', action='append', required=True)
    parser.add_argument('--operational-from', default='2026-07-08')
    args = parser.parse_args()
    specs = []
    for raw in args.bank:
        name, a, inc, out, z, active = raw.split(':')
        specs.append((name, int(a), int(inc), int(out), int(z), active))
    with open(args.daily_json, encoding='utf-8') as source:
        ledger = json.load(source)
    selected = {3} | {row for _, *numbers, _ in specs for row in numbers}
    with zipfile.ZipFile(args.workbook) as archive:
        rows = saved_rows(archive, sheet_member(archive, 'Fluxo de Caixa'), selected)
    print(json.dumps(reconcile(rows, specs, ledger, dt.date.fromisoformat(args.operational_from)), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
