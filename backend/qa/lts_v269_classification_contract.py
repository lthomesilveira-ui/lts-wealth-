"""Independent final-source synthetic classification review; no external writes."""
from pathlib import Path
import importlib.util, unittest, sqlite3, re
p=Path('backend/qa/lts_v269_origin_base.py')
spec=importlib.util.spec_from_file_location('origin',p); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.CANDIDATE=Path('backend/patches/v269/lts_card_source_rows_pre_v262.sql').read_text()
suite=unittest.TestSuite(m.OriginTests(n) for n in unittest.defaultTestLoader.getTestCaseNames(m.OriginTests) if n!='test_no_broadened_installment_join_or_financial_changes')
result=unittest.TextTestRunner(verbosity=1).run(suite)
assert result.wasSuccessful()
source=m.CANDIDATE
frag=source.split('with installment_decisions as materialized (',1)[1].split(' from public.lts_open_finance_staging',1)[0]
frag=frag[frag.index('case when'):]
with sqlite3.connect(':memory:') as c:
 c.execute('CREATE TABLE d(category_label text,beneficiary text)')
 for rows,expected in [([('Saúde',None),('Saúde','Benjamin')],(None,None)),([('Saúde',None),('Saúde',None)],('Saúde',None)),([('Saúde','Benjamin'),('Saúde','Benjamin')],('Saúde','Benjamin')),([('Saúde','Rafiki')],('Saúde','Rafiki')),([('Saúde','Benjamin'),('Saúde','Larissa')],(None,None))]:
  c.execute('DELETE FROM d');c.executemany('INSERT INTO d VALUES (?,?)',rows)
  actual=c.execute('SELECT '+frag+' FROM d').fetchone(); assert actual==expected,(rows,actual,expected)
print('PASS 17 final-source precedence cases and 5 NULL-sensitive installment consensus cases. SQLite bounded expression test, not PostgreSQL execution.')
