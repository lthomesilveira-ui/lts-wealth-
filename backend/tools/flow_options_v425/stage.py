"""Store tested generic release objects only; no commits, ref updates or deployment."""
from pathlib import Path
import os,json,hashlib,urllib.request,re
ROOT=Path(__file__).resolve().parents[3];out=ROOT/'qa/v425';head=os.environ['REVIEWED_HEAD']
assert re.fullmatch('[0-9a-f]{40}',head) and (ROOT/'.git/HEAD').read_text().strip()==head
proof=json.loads((out/'result.json').read_text());assert proof['pass'] and len(proof['results'])==8
base='https://api.github.com/repos/'+os.environ['GITHUB_REPOSITORY']
headers={'Authorization':'Bearer '+os.environ['GITHUB_TOKEN'],'Accept':'application/vnd.github+json'}
def call(path,body=None):
 req=urllib.request.Request(base+path,headers=headers,data=None if body is None else json.dumps(body).encode())
 with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
def blobsha(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
entries=[]
for p in sorted((ROOT/'releases/v425').iterdir()):
 assert p.is_file() and not p.is_symlink();data=p.read_bytes();sha=blobsha(data);prior=ROOT/'releases/v423'/p.name
 if not prior.exists() or prior.read_bytes()!=data:assert call('/git/blobs',{'content':data.decode(),'encoding':'utf-8'})['sha']==sha
 entries.append({'path':p.name,'mode':'100644','type':'blob','sha':sha})
tree=call('/git/trees',{'tree':entries});base_tree=call('/git/commits/'+head)['tree']['sha']
root=call('/git/trees',{'base_tree':base_tree,'tree':[{'path':'releases/v425','mode':'040000','type':'tree','sha':tree['sha']}]})
result={'head':head,'base_tree':base_tree,'release_tree':tree['sha'],'candidate_tree':root['sha'],'refs_modified':False,'commits_created':False,'published':False}
(out/'staged.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
