"""Export reviewed promotion bytes for the authorized repository connector.

The test job has read-only repository access. It never writes Git objects,
commits, branches or workflow files through the GitHub API.
"""
import os,json,subprocess,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
head=os.environ['REVIEWED_HEAD'];out=Path(os.environ['V417_EVIDENCE'])
assert len(head)==40 and all(c in '0123456789abcdef' for c in head)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==head
assert json.loads((out/'render-result.json').read_text())['passed']
assert json.loads((ROOT/'mobile/current.json').read_text())=={'release':'v417','entry':'../releases/v417/app.html'}
assert (out/'prior-release-gates.txt').stat().st_size>0
entries=[]
for name in ['mobile/current.json','.github/workflows/pages.yml','.github/scripts/lts_v417_verify_published.cjs']:
 p=ROOT/name;data=p.read_bytes();dest=out/'promotion'/name
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
 entries.append({'path':name,'mode':'100644','type':'blob',
  'sha':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),
  'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
result={'head':head,'base_tree':subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=ROOT,text=True).strip(),
 'files':entries,'api_writes':0,'refs_modified':False,'commits_created':False,
 'note':'Apply only through the authorized repository connector after reviewing these exact bytes.'}
(out/'promotion-manifest.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
