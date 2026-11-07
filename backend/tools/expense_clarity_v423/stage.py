"""Stage reviewed generic objects only; never write refs or deploy."""
from pathlib import Path
import json,os,hashlib,urllib.request,re
from prepare_promotion import prepare
ROOT=Path(__file__).resolve().parents[3];out=ROOT/'qa/v423';head=os.environ['REVIEWED_HEAD']
assert re.fullmatch(r'[0-9a-f]{40}',head)
assert (ROOT/'.git').is_dir() and not (ROOT/'.git').is_symlink()
assert (ROOT/'.git/HEAD').read_text().strip()==head
assert json.loads((out/'browser.json').read_text())['passed']
assert json.loads((out/'unit.json').read_text())['passed']
promotion_files=prepare(ROOT,out)
base_url='https://api.github.com/repos/'+os.environ['GITHUB_REPOSITORY'];headers={'Authorization':'Bearer '+os.environ['GITHUB_TOKEN'],'Accept':'application/vnd.github+json'}
def api(path,body=None):
 req=urllib.request.Request(base_url+path,headers=headers,data=None if body is None else json.dumps(body).encode())
 with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
def sha(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def store(p):
 data=p.read_bytes();h=sha(data);assert api('/git/blobs',{'content':data.decode(),'encoding':'utf-8'})['sha']==h;return h
entries=[]
for p in sorted((ROOT/'releases/v423').iterdir()):
 assert p.is_file() and not p.is_symlink();data=p.read_bytes();h=sha(data);prior=ROOT/'releases/v421'/p.name
 if not prior.exists() or data!=prior.read_bytes():assert store(p)==h
 entries.append({'path':p.name,'mode':'100644','type':'blob','sha':h})
subtree=api('/git/trees',{'tree':entries});base=api('/git/commits/'+head)['tree']['sha']
tree=api('/git/trees',{'base_tree':base,'tree':[{'path':'releases/v423','mode':'040000','type':'tree','sha':subtree['sha']}]})
# Export exact promotion blobs for separate review through the authorized
# repository connector. Do not create a workflow-changing root tree here.
promotion=[{'path':name,'mode':'100644','type':'blob','sha':store(ROOT/name)} for name in promotion_files]
result={'head':head,'base_tree':base,'candidate_tree':tree['sha'],'release_tree':subtree['sha'],'refs_modified':False,'commits_created':False,'changed_root_path':'releases/v423','promotion_entries':promotion,'promotion_applied':False}
(out/'staged.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
