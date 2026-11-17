"""Build the next immutable Flow copy correction from V463."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'releases/v463'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)

def build(target):
    shutil.copytree(BASE, target)
    app = target / 'app.html'
    text = app.read_text()
    assert text.count('V463') == 5
    app.write_text(text.replace('V463', 'V466'))
    index = target / 'index.html'
    text = replace_once(index.read_text(), "if(isCardSettlement(e))return 'Consulte composição e eventuais pendências em Abrir fatura';", "if(isCardSettlement(e))return '';")
    for label in ['Categoria analítica: Seguros', 'Categoria analítica: Salário', 'Categoria analítica: Impostos do Imóvel']:
        text = replace_once(text, "return '" + label + "'", "return ''")
    index.write_text(text)
    style = target / 'lts-v463-customer.css'
    style.write_text(style.read_text() + '.fx89-detail-desc>small{display:block;margin-top:4px;line-height:1.4;white-space:normal}\n')
    provenance = {'release': 'v466', 'base_release': 'v463', 'scope': 'Concise Flow movement labels and readable material notes; V463 financial controls retained', 'financial_source_writes': False, 'authentication_changed': False, 'timeouts_changed': False, 'published_base_immutable': True, 'physical_mobile_validated': False}
    (target / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    manifest = json.loads((BASE / 'manifest.json').read_text())
    manifest.update(release='v466', version='v466', base_release='v463', protected_manifest={'path': 'releases/v463/manifest.json', 'sha256': digest(BASE / 'manifest.json')})
    manifest['files'] = {p.name: digest(p) for p in sorted(target.iterdir()) if p.name != 'manifest.json'}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as temporary:
        generated = Path(temporary) / 'v466'
        build(generated)
        actual = ROOT / 'releases/v466'
        if args.check:
            assert {p.name: p.read_bytes() for p in actual.iterdir()} == {p.name: p.read_bytes() for p in generated.iterdir()}
        else:
            assert not actual.exists(), 'Never overwrite a published release'
            shutil.copytree(generated, actual)
    print(json.dumps({'pass': True, 'release': 'v466', 'protected_base': 'v463'}))
