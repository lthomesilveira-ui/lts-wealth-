"""Build an immutable release that refreshes review rows after card decisions."""
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PREVIOUS = ROOT / 'releases/v436'
RELEASE = ROOT / 'releases/v439'
ANCHOR = '  async function ensureReconciliation(force=false){'
INSERT = '''  function refreshReviewAfterCardClassification(){
   syncReviewSession();
   const s=state.review;
   // A read started before the saved decision must not restore its old rows.
   // Keep the known list and drafts until a new bounded read succeeds.
   s.sequence=(s.sequence||0)+1;s.status='idle';s.error=null;
   if(D)void ensureReview(true);
  }
  window.addEventListener('lts:card-classified',refreshReviewAfterCardClassification);
'''

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def update(source):
    assert source.count(ANCHOR) == 1
    assert 'refreshReviewAfterCardClassification' not in source
    return source.replace(ANCHOR, INSERT + ANCHOR)

def build(output):
    prior_path = PREVIOUS / 'manifest.json'
    manifest = json.loads(prior_path.read_text())
    assert manifest['release'] == 'v436'
    assert set(manifest['files']) | {'manifest.json'} == {p.name for p in PREVIOUS.iterdir()}
    for name, expected in manifest['files'].items():
        assert sha(PREVIOUS / name) == expected, name
    shutil.copytree(PREVIOUS, output)
    for name in ['lts-v181-regression-closure.js', 'lts-v384-startup-1.js']:
        (output / name).write_text(update((PREVIOUS / name).read_text()))
    (output / 'app.html').write_text((PREVIOUS / 'app.html').read_text().replace('V436', 'V439'))
    provenance = {
        'release': 'v439', 'base_release': 'v436',
        'scope': 'refresh the outgoing review list after a successful card classification',
        'financial_values_changed': False, 'mutation_paths_changed': False,
        'query_arguments_changed': False, 'cache_or_auth_policy_changed': False,
    }
    (output / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    manifest.update(release='v439', version='v439', base_release='v436',
                    protected_manifest={'path': 'releases/v436/manifest.json', 'sha256': sha(prior_path)})
    manifest['files'] = {name: sha(output / name) for name in sorted(manifest['files'])}
    changed = {name for name in manifest['files'] if sha(output / name) != sha(PREVIOUS / name)}
    assert changed == {'app.html', 'provenance.json', 'lts-v181-regression-closure.js', 'lts-v384-startup-1.js'}, changed
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    return len(manifest['files'])

if __name__ == '__main__':
    with tempfile.TemporaryDirectory(dir=RELEASE.parent) as work:
        candidate = Path(work) / RELEASE.name
        count = build(candidate)
        if RELEASE.exists():
            assert {p.name: sha(p) for p in candidate.iterdir()} == {p.name: sha(p) for p in RELEASE.iterdir()}
        else:
            candidate.rename(RELEASE)
    print(json.dumps({'pass': True, 'release': 'v439', 'assets': count, 'predecessor_unchanged': True}))
