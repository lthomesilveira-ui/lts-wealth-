"""Stage generic release objects only after tests. Never commit, update refs or deploy."""
import json,os,hashlib,urllib.request,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];head=os.environ['REVIEWED_HEAD'];out=ROOT/'qa/v421'
# checkout@v4 explicitly selects this reviewed SHA in detached mode. Read its
# local metadata without changing global safe.directory or repository ownership.
assert re.fullmatch(r'[0-9a-f]{40}',head)
assert (ROOT/'.git').is_dir() and not (ROOT/'.git').is_symlink()
assert (ROOT/'.git/HEAD').read_text().strip()==head,'reviewed detached checkout required'
assert json.loads((out/'result.json').read_text())['passed']
assert json.loads((out/'unit.json').read_text())['passed']
api='https://api.github.com/repos/'+os.environ['GITHUB_REPOSITORY']
headers={'Authorization':'Bearer '+os.environ['GITHUB_TOKEN'],'Accept':'application/vnd.github+json'}
def call(path,body=None):
 req=urllib.request.Request(api+path,headers=headers,data=None if body is None else json.dumps(body).encode())
 with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
def gitsha(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
entries=[]
for p in sorted((ROOT/'releases/v421').iterdir()):
 assert p.is_file() and not p.is_symlink();data=p.read_bytes();sha=gitsha(data);prior=ROOT/'releases/v417'/p.name
 if not prior.exists() or data!=prior.read_bytes():assert call('/git/blobs',{'content':data.decode(),'encoding':'utf-8'})['sha']==sha
 entries.append({'path':p.name,'mode':'100644','type':'blob','sha':sha})
subtree=call('/git/trees',{'tree':entries});base=call('/git/commits/'+head)['tree']['sha']
tree=call('/git/trees',{'base_tree':base,'tree':[{'path':'releases/v421','mode':'040000','type':'tree','sha':subtree['sha']}]})
result={'head':head,'base_tree':base,'candidate_tree':tree['sha'],'release_tree':subtree['sha'],'refs_modified':False,'commits_created':False,'changed_root_path':'releases/v421'}
(out/'staged.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
