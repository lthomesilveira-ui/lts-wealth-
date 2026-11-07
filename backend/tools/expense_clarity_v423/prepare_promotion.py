"""Prepare exact promotion files without a branch write or deployment."""
from pathlib import Path
import json,subprocess,textwrap

def prepare(root:Path,out:Path):
 changes={}
 def put(name,text):
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True)
  if p.exists() and p.read_text()==text:return
  p.write_text(text);changes[name]=text
 for p in (root/'.github/workflows').glob('*.yml'):
  s=p.read_text();t=s.replace('LTS_MOBILE_RELEASE: v421','LTS_MOBILE_RELEASE: v423').replace('LTS_MOBILE_RELEASE=v421','LTS_MOBILE_RELEASE=v423')
  if p.name=='pages.yml':
   t=t.replace("paths: ['releases/v421/**'","paths: ['releases/v423/**','releases/v421/**'")
   t=t.replace('lts_v421_verify_published.cjs','lts_v423_verify_published.cjs').replace('v421-published-verification','v423-published-verification').replace('Verify published V421','Verify published V423')
   t=t.replace('          node .github/scripts/lts_v421_release_contract.cjs','          LTS_MOBILE_RELEASE=v423 node .github/scripts/lts_v421_release_contract.cjs')
   marker='      - name: Configure Pages';assert marker in t
   if 'node .github/scripts/lts_v423_release_contract.cjs' not in t:t=t.replace(marker,'          node .github/scripts/lts_v423_release_contract.cjs\n'+marker)
  put(str(p.relative_to(root)),t)
 name='.github/scripts/lts_v421_release_contract.cjs';s=(root/name).read_text()
 old="assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v421',entry:'../releases/v421/app.html'});"
 new="const entry=process.env.LTS_MOBILE_RELEASE||'v421';assert.match(entry,/^v[0-9]+$/);assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:entry,entry:'../releases/'+entry+'/app.html'});"
 assert old in s or new in s;put(name,s.replace(old,new))
 name='.github/scripts/lts_v412_projection_browser.cjs';s=(root/name).read_text();put(name,s.replace('v(?:417|421)','v(?:417|421|423)'))
 name='.github/scripts/lts_v385_browser.cjs';s=(root/name).read_text();put(name,s.replace("new URL(frame.url()).pathname.includes('/releases/v421/')","/\\/releases\\/v(?:421|423)\\//.test(new URL(frame.url()).pathname)"))
 name='.github/scripts/lts_v415_refresh_current_entry.cjs';s=(root/name).read_text();put(name,s.replace("release==='v421'","['v421','v423'].includes(release)"))
 s=(root/'.github/scripts/lts_v421_verify_published.cjs').read_text()
 s=s.replace("['v421','v417'","['v423','v421','v417'").replace("{release:'v421',entry:'../releases/v421/app.html'}","{release:'v423',entry:'../releases/v423/app.html'}").replace('v421-published-verification','v423-published-verification').replace("ui:'v421'","ui:'v423'").replace("previous_ui:['v417'","previous_ui:['v421','v417'")
 put('.github/scripts/lts_v423_verify_published.cjs',s)
 put('mobile/current.json',json.dumps({'release':'v423','entry':'../releases/v423/app.html'},indent=2)+'\n')
 contract="""'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='releases/v423',m=JSON.parse(fs.readFileSync(root+'/manifest.json')),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v423');assert.equal(m.base_release,'v421');
for(const[n,h]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,n))),h,n);
assert.deepEqual(Object.keys(m.files).concat('manifest.json').sort(),fs.readdirSync(root).sort());
assert.equal(sha(fs.readFileSync('releases/v421/manifest.json')),m.protected_manifest.sha256);
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v423',entry:'../releases/v423/app.html'});
const app=fs.readFileSync(root+'/app.html','utf8');assert(app.indexOf('<script src="lts-v423-clarity-model.js"')<app.indexOf('<script src="lts-v384-startup-1.js"'));
console.log(JSON.stringify({passed:true,release:'v423',assets:Object.keys(m.files).length,predecessor_unchanged:true}));
"""
 put('.github/scripts/lts_v423_release_contract.cjs',contract)
 text=(root/'.github/workflows/pages.yml').read_text();marker='      - name: Verify release assets and protected history\n        run: |\n';assert marker in text
 commands=textwrap.dedent(text.split(marker,1)[1].split('      - name: Configure Pages',1)[0]);assert commands.count('node .github/scripts/')>=70
 result=subprocess.run(['bash','-euo','pipefail','-c',commands],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/'promotion-static-gates.txt').write_text(result.stdout);assert result.returncode==0,result.stdout[-3000:]
 for name,text in changes.items():
  dest=out/'promotion'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
 return sorted(changes)
