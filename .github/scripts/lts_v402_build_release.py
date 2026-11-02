"""Copy the immutable prior release; change only the wrapper and source disclosure."""
import hashlib
import json
import shutil
from pathlib import Path

root=Path(__file__).resolve().parents[2]
base=root/'releases/v399'
dest=root/'releases/v402'
dest.mkdir(exist_ok=True)
for f in base.iterdir():
 if f.is_file():shutil.copyfile(f,dest/f.name)
app=(base/'app.html').read_text().replace('V399','V402').replace('v399-dated-d01-20261102','v402-daily-cofrinho-20261102').replace('src="lts-v399-d01-composition.js"','src="lts-v402-d01-composition.js"')
(dest/'app.html').write_text(app)
shutil.copyfile(root/'frontend/lts-v402-d01-composition.js',dest/'lts-v402-d01-composition.js')
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protected={f.name:digest(f) for f in base.iterdir() if f.is_file()}
provenance={'release':'v402','base_release':'v399','scope':'daily Cofrinho source composition and timestamps',
 'protected_base_files':protected,'original_financial_sources_changed':False,
 'original_cash_forecasts_changed':False,'financial_calculations_in_frontend':False,
 'backend_daily_position_reader_changed':True,'private_http_validated':False,
 'physical_mobile_validated':False,'published_releases_immutable':True}
(dest/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
manifest={'release':'v402','base_release':'v399','entry':'app.html',
 'files':{f.name:digest(f) for f in sorted(dest.iterdir()) if f.is_file() and f.name!='manifest.json'},
 'protected_manifest':{'path':'releases/v399/manifest.json','sha256':digest(base/'manifest.json')}}
(dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(root/'mobile/current.json').write_text(json.dumps({'release':'v402','entry':'../releases/v402/app.html'},indent=2)+'\n')
