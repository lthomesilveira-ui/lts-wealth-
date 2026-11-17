"""Read-only native PostgreSQL tests using real report, scope and detail functions."""
import json
import subprocess
import unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent
DB='lts_expense_payment_scope_v464'
U='00000000-0000-4000-8000-000000000001'
FROM='2020-01-01';TO='2020-01-31'
def sql(q,error=None):
 p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],input='SET check_function_bodies=off;'+q,text=True,capture_output=True)
 if error:
  assert p.returncode and error in p.stderr,(error,p.stderr)
  return p.stderr
 if p.returncode:raise AssertionError(p.stderr)
 return p.stdout.strip()
def attrs(sig):return sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{sig}'::regprocedure;")
def detail(scope=None,offset=0,limit=500,prefix=''):
 return json.loads(sql(prefix+f"SELECT public.lts_browser_expense_detail_v353('{FROM}','{TO}','{json.dumps(scope or {})}',{offset},{limit},NULL);"))
def report(prefix=''):return json.loads(sql(prefix+f"SELECT public.lts_browser_expenses_v229('{FROM}','{TO}');"))
class PaymentScope(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  build.build();subprocess.run(['createdb',DB],check=True,capture_output=True)
  sql((ROOT/'setup.sql').read_text());sql((ROOT/'node-fixture.sql').read_text())
  for k in build.SPECS:sql((ROOT/(k+'-original.sql')).read_text())
  sql((ROOT/'view-rows-fixture.sql').read_text());sql((ROOT/'seed.sql').read_text())
  cls.old_report=report();cls.old_profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
  cls.attributes={sig:attrs(sig) for sig in build.SPECS.values()}
  sql((ROOT/'install.sql').read_text())
 def setUp(self):sql((ROOT/'seed.sql').read_text())
 def test_01_all_cards_accounts_and_total_share_the_same_rows(self):
  all_=detail();cards=detail({'payment':'card'});accounts=detail({'payment':'account'})
  self.assertEqual((all_['total'],cards['total'],accounts['total']),(420,340,80))
  self.assertEqual(set(r['key'] for r in all_['rows']),set(r['key'] for r in cards['rows'])|set(r['key'] for r in accounts['rows']))
  self.assertFalse(set(r['key'] for r in cards['rows'])&set(r['key'] for r in accounts['rows']))
 def test_02_category_detail_combines_cards_and_cash_and_keeps_refunds(self):
  self.assertEqual(detail({'macrogroup':'Saúde'})['total'],110)
  self.assertEqual(detail({'macrogroup':'Saúde','payment':'card'})['total'],90)
  self.assertEqual(detail({'macrogroup':'Saúde','payment':'account'})['total'],20)
  self.assertEqual(detail({'macrogroup':'Alimentação','category':'iFood'})['total'],25)
  self.assertEqual(detail({'payment':'card','sign':'compensations'})['total'],-10)
 def test_03_channel_cells_reconcile_to_unchanged_report_summary(self):
  r=report();self.assertEqual(r['summary'],self.old_report['summary'])
  cells=r['presentation']['cells'];self.assertTrue(all(c['payment'] in ('card','account') for c in cells))
  self.assertEqual(sum(c['net'] for c in cells),420)
  self.assertEqual(sum(c['net'] for c in cells if c['payment']=='card'),r['summary']['card_total'])
  self.assertEqual(sum(c['net'] for c in cells if c['payment']=='account'),r['summary']['account_total'])
 def test_04_original_person_category_and_precise_gift_label(self):
  cells=report()['presentation']['cells']
  self.assertFalse(any(c['macrogroup']=='Vida pessoal e familiar' for c in cells))
  self.assertEqual(next(c for c in cells if c['category']=='Benjamin')['macrogroup'],'Benjamin')
  self.assertEqual(detail({'macrogroup':'Presentes e contribuições'})['total'],15)
  self.assertEqual(detail({'category':'Benjamin'})['rows'][0]['current_category'],'Benjamin')
 def test_05_unknown_filter_rejected_and_owner_date_pagination_preserved(self):
  for scope in [{'payment':'anything'},{'other_field':'card'}]:
   sql(f"SELECT public.lts_browser_expense_detail_v353('{FROM}','{TO}','{json.dumps(scope)}',0,500,NULL);",error='invalid detail range or filters')
  first=detail({'payment':'card'},limit=2);second=detail({'payment':'card'},offset=2,limit=2)
  self.assertEqual(first['next_offset'],2);self.assertIsNone(second['next_offset'])
  self.assertEqual(len({r['key'] for r in first['rows']+second['rows']}),4)
  self.assertEqual(detail(prefix="SET lts_test.user='00000000-0000-4000-8000-000000000099';")['total'],999)
 def test_06_old_cached_presentation_is_not_reused(self):
  sql(f"INSERT INTO lts_v229_read_cache VALUES('{U}','expenses_v251',current_date,'{FROM}','{TO}','{{\"old_presentation\":true}}',now(),'expenses-v353:1:'||current_date::text);")
  self.assertNotIn('old_presentation',report())
  self.assertTrue(sql("SELECT source_fingerprint FROM lts_v229_read_cache;").startswith('expenses-v464:'))
 def test_07_read_only_call_exact_metadata_and_source_parity(self):
  before=sql('SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY row_key)::text) FROM fixture_expenses f;')
  self.assertEqual(detail({'payment':'card'},prefix='BEGIN READ ONLY;')['total'],340)
  self.assertEqual(report('BEGIN READ ONLY;')['summary']['selected_total'],420)
  for sig in build.SPECS.values():self.assertEqual(attrs(sig),self.attributes[sig])
  self.assertEqual(sql('SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY row_key)::text) FROM fixture_expenses f;'),before)
 def test_08_closed_profile_only_adds_exactly_five_reviewed_producers(self):
  p=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
  self.assertEqual(p['producers'][:-5],self.old_profile['producers'])
  self.assertEqual({k:v for k,v in p.items() if k!='producers'},{k:v for k,v in self.old_profile.items() if k!='producers'})
  for entry in p['producers'][-5:]:self.assertEqual(entry['md5'],sql(f"SELECT md5(pg_get_functiondef('{entry['signature']}'::regprocedure));"))
 def test_09_guarded_idempotent_install_rollback_and_active_worker_refusal(self):
  sql((ROOT/'install.sql').read_text());sql((ROOT/'rollback.sql').read_text())
  for k,sig in build.SPECS.items():self.assertEqual(sql(f"SELECT md5(pg_get_functiondef('{sig}'::regprocedure));"),build.md5(build.definition(k+'-original.sql')))
  sql((ROOT/'install.sql').read_text());sql("UPDATE lts_product_refresh_private_v415.queue SET state='running';")
  sql((ROOT/'install.sql').read_text(),error='V464_WORKER_ACTIVE');sql("UPDATE lts_product_refresh_private_v415.queue SET state='ready';")
if __name__=='__main__':unittest.main(verbosity=2)
