"""Offline public-package checks. Uses no database, network, or private inputs."""
from pathlib import Path
import hashlib,json,re,unittest
from connection_config import local_connection_options
P=Path(__file__).resolve().parent
DECL=re.compile(r'(v_(\w+) jsonb := )\$json\$(.*?)\$json\$(::jsonb;)',re.S)
def digest(s):return hashlib.sha256(s.encode()).hexdigest()
def declarations(kind):return {m[2]:json.loads(m[3]) for m in DECL.finditer((P/f'{kind}.review.sql').read_text())}
def logic(s):return DECL.sub(lambda m:m[1]+'$json$<'+m[2]+'>$json$'+m[4],s)
class StaticContract(unittest.TestCase):
 def setUp(self):
  self.f=json.loads((P/'fixtures.json').read_text());self.m=json.loads((P/'source-contract.json').read_text())
 def test_fixtures_are_synthetic_and_consistent(self):
  self.assertEqual((len(self.f['old']),len(self.f['new']),len(self.f['legacy'])),(36,24,12))
  rows=self.f['old']+self.f['new'];self.assertEqual(len(set(r['id'] for r in rows)),60)
  for r in rows:
   self.assertRegex(r['id'],r'^f0000000-0000-4000-8000-[0-9a-f]{12}$')
   self.assertEqual(r['metadata']['contract_ref'],'QA001')
   self.assertEqual(r['metadata']['source_document'],'synthetic-schedule.pdf')
   self.assertEqual(r['amount'],-(1000+r['metadata']['installment_number']-1))
   self.assertEqual(r['is_suppressed'],False)
  self.assertEqual(self.f['old'][-1]['event_date'],'2039-12-20')
  self.assertEqual(self.f['new'][0]['event_date'],'2040-01-20')
  self.assertEqual(self.f['new'][-1]['event_date'],'2041-12-20')
 def test_extracted_logic_is_frozen(self):
  for kind in ['apply','recovery']:
   s=(P/f'{kind}.review.sql').read_text()
   self.assertEqual(digest(logic(s)),self.m['synthetic_logic_sha256'][kind])
   self.assertIn('BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;',s)
   self.assertTrue(s.rstrip().endswith('ROLLBACK;'))
   self.assertNotIn('COMMIT',s)
   self.assertNotRegex(s,r'(?i)DELETE\s+FROM\s+public\.financial_events')
   self.assertEqual(len(re.findall(r'IS DISTINCT FROM',s)),len(re.findall(r'IS DISTINCT FROM',logic(s))))
 def test_fixture_declarations_match(self):
  contract=json.loads((P/'structural-contract.json').read_text())
  for kind in ['apply','recovery']:
   d=declarations(kind)
   self.assertEqual(set(d),{'old','new','rule','rule_after','legacy','triggers','constraints'})
   for key in d:self.assertEqual(d[key],self.f[key] if key in self.f else contract[key])
  self.assertEqual(len(contract['constraints']),7);self.assertEqual(len(contract['triggers']),9)
 def test_helpers_are_byte_identical_to_leases(self):
  for name,file in [('owner','owner.sql'),('cache','cache-trigger.sql'),('block_delete','block-delete.sql')]:
   self.assertEqual(hashlib.md5((P/file).read_bytes()).hexdigest(),self.m['helper_md5'][name])
   if name in {'owner','cache'}:
    for kind in ['apply','recovery']:self.assertIn(self.m['helper_md5'][name],(P/f'{kind}.review.sql').read_text())
 def test_only_legacy_predicate_is_included(self):
  s=(P/'legacy-suppression-predicate.sql').read_text()
  self.assertEqual(digest(s),self.m['legacy_predicate_sha256'])
  self.assertTrue(s.startswith('not exists('))
  for token in ['r.user_id=p_user_id','r.active=true',"r.source_table='evento_base'",'r.description_exact','r.account_exact','r.date_from','r.date_to']:self.assertIn(token,s)
  self.assertNotIn('CREATE FUNCTION',s)
 def test_no_non_synthetic_identifiers(self):
  for f in P.rglob('*'):
   if not f.is_file() or f.suffix in {'.pyc'} or f.name in {'offline-result.txt'}:continue
   text=f.read_text()
   for value in re.findall(r'\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b',text):
    self.assertTrue(value.startswith('f0000000-0000-4000-8000-'),f'{f.name}: non-fixture UUID')
   self.assertNotRegex(text,r'https?://[^\s]*supabase')
 def test_no_unlisted_publishable_files(self):
  pin=json.loads((P/'package-checksums.json').read_text())
  allowed=set(pin)|{'package-checksums.json','offline-result.txt','postgres16-result.txt','documentary-postgres16-result.txt'}
  for artifact in P.rglob('*'):
   if not artifact.is_file() or '__pycache__' in artifact.parts:continue
   self.assertIn(str(artifact.relative_to(P)),allowed,'Unexpected file must be reviewed before publication')
 def test_transport_is_loopback_even_with_hostaddr_override(self):
  for host,address in [('localhost','127.0.0.1'),('127.0.0.1','127.0.0.1'),('::1','::1')]:
   options=local_connection_options({'PGHOST':host,'PGHOSTADDR':'203.0.113.254'})
   self.assertEqual(options['hostaddr'],address)
   self.assertEqual(options['host'],host)
 def test_transport_rejects_remote_hosts_and_services(self):
  for env in [{'PGHOST':'203.0.113.254'},{'PGHOST':'db.example.invalid'},{'PGSERVICE':'remote_service'},{'PGSERVICEFILE':'unexpected.conf'},{'PGPORT':'0'}]:
   with self.assertRaises(RuntimeError):local_connection_options(env)
 def test_public_source_exceptions_are_exact_and_bounded(self):
  exceptions=json.loads((P/'public-source-exceptions.json').read_text())
  allowed={'988bbf5211676af0b543b766bf1556af242b4317c5174579f2c5f2f8514a2924', '002397353222cba921d615fec43032626bdf18d273b8dd3cb1b3f18bd9c29697', 'af45d1fe61e381a2eab0b12b0beeaa9e54e58c1a3f82f0d45f8e989c9219c6ad', '7881970b807c3ad6c807aca63e78cdef0845e67b95e1e17dc21c4dec269dec6e'}
  for name,entry in exceptions['files'].items():
   self.assertTrue(name.startswith('documentary_') and '/' not in name)
   self.assertLessEqual({hashlib.sha256(x.encode()).hexdigest() for x in entry['identifiers']},allowed)
   self.assertEqual(hashlib.sha256((P/name).read_bytes()).hexdigest(),entry['sha256'])
 def test_public_manifest_only_describes_published_artifacts(self):
  self.assertEqual(set(self.m),{'purpose','synthetic_logic_sha256','fixture_sizes','schema','helper_md5','legacy_predicate_sha256'})
 def test_complete_package_hashes(self):
  pin=json.loads((P/'package-checksums.json').read_text())
  for name,expected in pin.items():
   artifact=P/name
   # The workflow lives at the repository root after the documented copy step.
   if not artifact.exists() and name.startswith('.github/'):
    artifact=P.parent.parent/name
   self.assertEqual(hashlib.sha256(artifact.read_bytes()).hexdigest(),expected,name)
if __name__=='__main__':unittest.main(verbosity=2)
