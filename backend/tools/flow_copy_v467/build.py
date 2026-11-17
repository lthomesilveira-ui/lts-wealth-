"""Keep pending receipt language consistent across the complete Actions screen."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'releases/v466'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)

def build(target):
    shutil.copytree(BASE, target)
    app = target / 'app.html'
    content = app.read_text()
    assert content.count('V466') == 5
    app.write_text(content.replace('V466', 'V467'))
    old_model = (BASE / 'lts-v333-actions-model.js').read_text()
    new_model = once(old_model, ".forEach(x=>push({...x,origin:'cockpit'}));", ".forEach(x=>push({...x,detail:String(x.detail||'')==='Classificação conhecida; o pagamento desta obrigação ainda requer correspondência documental.'?'Movimentação ainda sem confirmação no banco.':x.detail,origin:'cockpit'}));")
    new_model = once(new_model, "'Há pagamento a confirmar. '", "'Há movimentações a confirmar. '")
    (target / 'lts-v333-actions-model.js').write_text(new_model)
    bundled = 0
    for name in ['lts-v384-startup-1.js', 'lts-v384-startup-2.js']:
        p = target / name
        content = p.read_text()
        if old_model in content:
            content = once(content, old_model, new_model)
            bundled += 1
            p.write_text(content)
    assert bundled == 1
    for name in ['lts-v181-regression-closure.js', 'lts-v384-startup-1.js']:
        p = target / name
        content = once(p.read_text(), 'Pagamentos ainda não identificados no banco', 'Movimentações a confirmar no banco')
        content = once(content, '<p class="v181-lead">Estas previsões continuam guardadas. Confira a data ou o pagamento antes de considerá-las realizadas.</p>', '')
        p.write_text(content)
    for name in ['lts-v225-open-finance.js', 'lts-v384-startup-2.js']:
        p = target / name
        content = once(p.read_text(), "data.transaction_count+' compras · '", "data.transaction_count+(Number(data.transaction_count)===1?' compra · ':' compras · ')")
        content = once(content, "(data.unclassified_count??0)+' compras precisam de categoria.</span>", "(data.unclassified_count??0)+(Number(data.unclassified_count??0)===1?' compra precisa de categoria.':' compras precisam de categoria.')+'</span>")
        p.write_text(content)
    recurring_copy = {' pagamento(s) a confirmar': ' a confirmar', 'Com pagamento a confirmar': 'Com movimentação a confirmar', 'Confira os meses sem previsão e os pagamentos ainda não identificados.': 'Confira as previsões e as movimentações a confirmar.', "awaiting:'Pagamento a confirmar'": "awaiting:'A confirmar'"}
    counts = {old: 0 for old in recurring_copy}
    for p in target.iterdir():
        if p.suffix not in ['.js', '.html']:
            continue
        content = p.read_text()
        for old, new in recurring_copy.items():
            counts[old] += content.count(old)
            content = content.replace(old, new)
        p.write_text(content)
    assert all(value >= 2 for value in counts.values()), counts
    provenance = {'release': 'v467', 'base_release': 'v466', 'scope': 'Consistent pending receipt and recurring confirmation copy across Actions; unchanged financial amounts, sources and confirmation states', 'financial_source_writes': False, 'authentication_changed': False, 'timeouts_changed': False, 'published_base_immutable': True, 'physical_mobile_validated': False}
    (target / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    manifest = json.loads((BASE / 'manifest.json').read_text())
    manifest.update(release='v467', version='v467', base_release='v466', protected_manifest={'path': 'releases/v466/manifest.json', 'sha256': digest(BASE / 'manifest.json')})
    manifest['files'] = {p.name: digest(p) for p in sorted(target.iterdir()) if p.name != 'manifest.json'}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as temporary:
        generated = Path(temporary) / 'v467'
        build(generated)
        actual = ROOT / 'releases/v467'
        if args.check:
            before = {p.name: p.read_bytes() for p in actual.iterdir()}
            after = {p.name: p.read_bytes() for p in generated.iterdir()}
            assert before == after, [name for name in sorted(before.keys() | after.keys()) if before.get(name) != after.get(name)]
        else:
            assert not actual.exists(), 'Never overwrite a published release'
            shutil.copytree(generated, actual)
    print(json.dumps({'pass': True, 'release': 'v467', 'protected_base': 'v466'}))
