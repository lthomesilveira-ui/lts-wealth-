"""Additive, reproducible UI release. Published V423 is immutable."""
from pathlib import Path
import hashlib,json,shutil,tempfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;SRC=ROOT/'releases/v423';TARGET=ROOT/'releases/v425'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((SRC/'manifest.json').read_text())
for n,h in m['files'].items():assert digest(SRC/n)==h,('protected asset changed',n)
work=tempfile.TemporaryDirectory() if TARGET.exists() else None
DST=Path(work.name)/'v425' if work else TARGET;shutil.copytree(SRC,DST)
shutil.copyfile(HERE/'options.js',DST/'lts-v425-flow-options.js')
p=DST/'app.html';s=p.read_text().replace('V423','V425').replace('v423-expense-cash-clarity','v425-flow-options')
anchor='<script src="lts-v423-clarity.js"></script>'
assert s.count(anchor)==1;s=s.replace(anchor,anchor+'\n<script src="lts-v425-flow-options.js"></script>');p.write_text(s)
(DST/'provenance.json').write_text(json.dumps({'release':'v425','base_release':'v423','scope':'Flow options and report hierarchy only','financial_values_changed':False,'new_financial_reads_or_writes':False,'private_session_verified':False,'physical_iphone_verified':False},indent=2)+'\n')
m.update(release='v425',version='v425',base_release='v423',protected_manifest={'path':'releases/v423/manifest.json','sha256':digest(SRC/'manifest.json')})
m['files']={n:digest(DST/n) for n in sorted(set(m['files'])|{'lts-v425-flow-options.js'})}
(DST/'manifest.json').write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
if work:
 assert {p.name:digest(p) for p in DST.iterdir()}=={p.name:digest(p) for p in TARGET.iterdir()},'candidate is not reproducible';work.cleanup()
print(json.dumps({'pass':True,'release':'v425','protected_predecessor':True,'assets':len(m['files'])}))
