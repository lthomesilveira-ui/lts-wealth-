"""Create a new immutable read-recovery release; never rewrite its predecessor."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
BASE = ROOT / 'releases/v442'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def build(target):
    shutil.copytree(BASE, target)
    app = target / 'app.html'
    app.write_text(app.read_text().replace('V442', 'V444'))
    transport = (SOURCE / 'read-transport.js').read_text()
    (target / 'lts-v227-read-transport.js').write_text(transport)
    bundle = target / 'lts-v384-startup-1.js'
    old = (BASE / 'lts-v227-read-transport.js').read_text()
    text = bundle.read_text()
    assert text.count(old) == 1
    bundle.write_text(text.replace(old, transport))
    shutil.copyfile(SOURCE / 'product-refresh.js', target / 'lts-v415-product-refresh.js')
    (target / 'provenance.json').write_text(json.dumps({
        'release': 'v444', 'base_release': 'v442',
        'scope': 'Cancel superseded reads and recover bounded transient product/status failures',
        'heavy_read_concurrency': 1, 'query_deadlines_changed': False,
        'financial_readers_changed': False, 'financial_writers_changed': False,
        'authentication_changed': False, 'canonical_promotion_requires_real_validation': True,
        'physical_mobile_validated': False,
    }, indent=2) + '\n')
    manifest = {'release': 'v444', 'version': 'v444', 'base_release': 'v442', 'entry': 'app.html',
                'protected_manifest': {'path': 'releases/v442/manifest.json', 'sha256': digest(BASE / 'manifest.json')},
                'files': {p.name: digest(p) for p in sorted(target.iterdir()) if p.name != 'manifest.json'}}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as temp:
        expected = Path(temp) / 'v444'
        build(expected)
        actual = ROOT / 'releases/v444'
        if args.check:
            assert {p.name: p.read_bytes() for p in actual.iterdir()} == {p.name: p.read_bytes() for p in expected.iterdir()}
        else:
            if actual.exists():
                shutil.rmtree(actual)
            shutil.copytree(expected, actual)
    print(json.dumps({'pass': True, 'release': 'v444', 'deterministic': True, 'base_unchanged': 'v442'}))
