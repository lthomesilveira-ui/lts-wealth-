"""Verify the faster reader against the original and test missing invoice evidence."""
import copy
import json
from pathlib import Path
import runpy

here = Path(__file__).resolve().parent
prior = runpy.run_path(str(here.parent / 'owner_budgets_v470/test_native.py'))
sql, append, calculate = (prior[name] for name in ('sql', 'append', 'calc'))
cards, baseline, plan = (prior[name] for name in ('cs', 'bl', 'plan'))

def output(source, entries):
    return append(c=source, b=entries)

incomplete = dict(cards, complete=False)
mismatched = copy.deepcopy(cards)
mismatched['cards'][0]['cycles'][0]['amount'] += 1
explicit_and_classified = baseline + [
    {'description':'Synthetic separate commitment', 'category':'Meals', 'signed_amount':-2.15,
     'event_date':'2026-12-27', 'account':'Synthetic checking', 'source_ref':'explicit-direct'}
]
cases = [(cards, baseline), (incomplete, baseline), (mismatched, baseline), (cards, explicit_and_classified)]
original = [output(*pair) for pair in cases]
original_calendar = calculate()
sql((here / 'install.sql').read_text())
for case, expected in zip(cases, original):
    assert output(*case) == expected
assert calculate() == original_calendar
duplicates = prior['cal'] + [prior['cal'][0]]
try:
    calculate(ca=duplicates)
except RuntimeError as error:
    assert 'compromissos do mês' in str(error)
else:
    raise AssertionError('a duplicate monthly commitment passed')

missing = copy.deepcopy(cards)
del missing['cards'][0]['cycles'][0]['amount']
result = output(missing, baseline)
row = next(s for s in result['series'] if s['series_key'] == 'owner_food')
first = row['coverage'][0]
assert first['trusted'] is False and first['known_brl'] is None and first['additional_brl'] is None
assert 'unreconciled_periods' in row['warnings']
assert not any(e.get('source_ref') == 'projection:v469:owner_food:2026-12-03' for e in result['events'])
for role in ('anon','authenticated','service_role'):
    assert sql(f"SELECT has_schema_privilege('{role}','lts_budget_private_v470','USAGE')") == 'f'
print(json.dumps({'pass':True,'parity_cases':5,'missing_invoice_total':'unknown','duplicate_period':'rejected'}))
