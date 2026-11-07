"""Stage only generic release objects. Do not create commits or update any ref."""
import os,json,subprocess,urllib.request,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];release=ROOT/'releases/v417'
repo=os.environ['GITHUB_REPOSITORY'];head=os.environ['REVIEWED_HEAD']
assert len(head)==40 and all(c in '0123456789abcdef' for c in head)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==head
assert json.loads((Path(os.environ['V417_EVIDENCE'])/'render-result.json').read_text())['passed']
base='https://api.github.com/repos/'+repo
headers={'Authorization':'Bearer '+os.environ['GITHUB_TOKEN'],'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'}
def api(path,data=None):
 req=urllib.request.Request(base+path,headers=headers,data=None if data is None else json.dumps(data).encode())
 with urllib.request.urlopen(req,timeout=30) as res:return json.load(res)
commit=api('/git/commits/'+head);entries=[]
for p in sorted(release.iterdir()):
 assert p.is_file() and not p.is_symlink()
 data=p.read_bytes();sha=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 original=ROOT/'releases/v415'/p.name
 if not original.exists() or data!=original.read_bytes():
  result=api('/git/blobs',{'content':data.decode('utf-8'),'encoding':'utf-8'});assert result['sha']==sha
 entries.append({'path':p.name,'mode':'100644','type':'blob','sha':sha})
subtree=api('/git/trees',{'tree':entries})
tree=api('/git/trees',{'base_tree':commit['tree']['sha'],'tree':[{'path':'releases/v417','mode':'040000','type':'tree','sha':subtree['sha']}]})
result={'head':head,'base_tree':commit['tree']['sha'],'candidate_tree':tree['sha'],'release_tree':subtree['sha'],'refs_modified':False,'commits_created':False,'changed_root_path':'releases/v417','assets':len(entries)}
(Path(os.environ['V417_EVIDENCE'])/'staged-tree.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
