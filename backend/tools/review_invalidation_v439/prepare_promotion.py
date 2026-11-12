"""Select the reviewed release while preserving historical financial assertions."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]

def put(path, text):
    path.write_text(text)

def replace(path, old, new):
    source = path.read_text()
    assert old in source or new in source, (str(path), old)
    put(path, source.replace(old, new))

def blob(text):
    data = text.encode()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()

for path in (ROOT / '.github/workflows').glob('*.yml'):
    source = path.read_text().replace('LTS_MOBILE_RELEASE: v436', 'LTS_MOBILE_RELEASE: v439').replace('LTS_MOBILE_RELEASE=v436', 'LTS_MOBILE_RELEASE=v439')
    if path.name == 'pages.yml':
        source = source.replace("paths: ['releases/v436/**'", "paths: ['releases/v439/**','releases/v436/**'")
        source = source.replace('Verify published V436', 'Verify published V439').replace('v436-published-verification', 'v439-published-verification')
        marker = '      - name: Configure Pages'
        if 'node .github/scripts/lts_v439_release_contract.cjs' not in source:
            assert marker in source
            source = source.replace('          node .github/scripts/lts_v436_release_contract.cjs', '          LTS_MOBILE_RELEASE=v439 node .github/scripts/lts_v436_release_contract.cjs')
            source = source.replace(marker, '          LTS_MOBILE_RELEASE=v439 node .github/scripts/lts_v439_release_contract.cjs\n' + marker)
    if path.name == 'v436-updates-recovery.yml' and 'LTS_MOBILE_RELEASE:' not in source:
        source = source.replace('    env:\n', '    env:\n      LTS_MOBILE_RELEASE: v439\n', 1)
    put(path, source)

path = ROOT / '.github/scripts/lts_v436_release_contract.cjs'
replace(path, "assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')), {release: 'v436', entry: '../releases/v436/app.html'});", "const entry=process.env.LTS_MOBILE_RELEASE||'v436';assert.match(entry,/^v[0-9]+$/);assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')), {release:entry,entry:'../releases/'+entry+'/app.html'});")

for suite, adapter in [('lts_v385_browser.cjs', 'lts_v385_current_entry.cjs'), ('lts_v412_projection_browser.cjs', 'lts_v425_projection_current_entry.cjs')]:
    path = ROOT / '.github/scripts' / suite
    before = path.read_text()
    after = before.replace('|433|436)', '|433|436|439)').replace("'/releases/v436/']", "'/releases/v436/','/releases/v439/']")
    put(path, after)
    adapter_path = ROOT / '.github/scripts' / adapter
    text = adapter_path.read_text()
    assert blob(before) in text or blob(after) in text
    put(adapter_path, text.replace(blob(before), blob(after)))

path = ROOT / '.github/scripts/lts_v385_current_entry.cjs'
replace(path, "'/releases/v436/']", "'/releases/v436/','/releases/v439/']")
path = ROOT / '.github/scripts/lts_v415_refresh_current_entry.cjs'
replace(path, "'v433','v436']", "'v433','v436','v439']")
path = ROOT / '.github/scripts/lts_v433_verify_published.cjs'
replace(path, "const previous=['v433'", "const previous=['v436','v433'")
put(ROOT / 'mobile/current.json', json.dumps({'release': 'v439', 'entry': '../releases/v439/app.html'}, indent=2) + '\n')

subprocess.run(['python3', 'backend/tools/report_presentation_v417/read_only_gates.py'], cwd=ROOT, check=True)
print(json.dumps({'pass': True, 'release': 'v439', 'prepared_only': True, 'refs_changed': False, 'published': False}))
