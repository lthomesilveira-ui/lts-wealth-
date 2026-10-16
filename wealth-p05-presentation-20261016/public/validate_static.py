from pathlib import Path
import hashlib,json,re,subprocess,sys
r=Path(__file__).parent
names=json.loads((r/'PUBLIC_FILES.json').read_text())['files']
assert len(names)==len(set(names))
for name in names:
 assert '/' not in name and '\\' not in name and name not in ['.','..']
 assert (r/name).is_file(),name
s=(r/'lts-v226-card-composition.js').read_text();original=(r/'v280-card-composition.original.js').read_text()
for marker in ['    async function openDetail(', '    function openOverview(', '    function paint(']:
 assert s[s.index(marker):]==original[original.index(marker):],marker
assert "rpc('lts_browser_card_cycles_v229')" in s
assert (r/'payment-refresh-annotation.sql').read_text().count('__SHARED_INVOICE_PREDICATE__')==0
sql=(r/'candidate-rollback-default.sql').read_text()
assert not re.search(r'\b(?:UPDATE|INSERT INTO|DELETE FROM|ALTER TABLE|CREATE TABLE)\b',sql,re.I)
assert not re.search(r'lts_expense_effective|lts_current_received|reconciliation_evidence',sql)
assert sql.endswith('ROLLBACK;\n')
assert 'SECURITY DEFINER' not in sql
for name in names:
 text=(r/name).read_text()
 if name!='validate_static.py':
  assert 'requestState' not in text,name
  assert not re.search(r'(?i)(supabase_service_role_key|postgres://|postgresql://)',text),name
subprocess.run(['node','--check',str(r/'lts-v226-card-composition.js')],check=True)
receipt={'status':'passed','files':{name:hashlib.sha256((r/name).read_bytes()).hexdigest() for name in names},'generation_guards_unchanged':True,'production_calls':0,'private_evidence_inputs':False}
(r/'STATIC_VALIDATION.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS: static package allowlist, exact V280 guards and restricted SQL.')
