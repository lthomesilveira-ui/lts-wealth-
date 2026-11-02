from pathlib import Path
import json,hashlib,shutil
r=Path(__file__).resolve().parents[2]
base=r/'releases/v398';out=r/'releases/v399';out.mkdir(exist_ok=True)
for f in base.iterdir():
 if f.is_file():shutil.copyfile(f,out/f.name)
app=(out/'app.html').read_text().replace('V398','V399').replace('v398-family-savings-20261101','v399-dated-d01-20261102')
app=app.replace('</body>','<script src="lts-v399-d01-composition.js"></script>\n</body>')
assert 'lts-v399-d01-composition.js' in app
(out/'app.html').write_text(app)
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((base/'manifest.json').read_text())
provenance={'release':'v399','base_release':'v398','purpose':'Dated Cofrinho flow composition and separate asset resources','protected_base_files':{f.name:hashfile(f)for f in base.iterdir()if f.is_file()},'private_http_validated':False,'physical_mobile_validated':False,'original_financial_sources_changed':False,'original_cash_forecasts_changed':False}
(out/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
m={'release':'v399','version':'v399','base_release':'v398','files':{f.name:hashfile(f)for f in sorted(out.iterdir())if f.is_file()and f.name!='manifest.json'},'protected':old['protected']}
(out/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(r/'mobile/current.json').write_text(json.dumps({'release':'v399','entry':'../releases/v399/app.html'},indent=2)+'\n')
print(json.dumps({'release':'v399','files':len(m['files'])+1,'prior_files_preserved':len(provenance['protected_base_files'])}))
