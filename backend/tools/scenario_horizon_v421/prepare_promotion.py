"""Prepare exact promotion files in the test workspace; never update refs."""
from pathlib import Path
import json,subprocess,textwrap

def prepare(root: Path, out: Path):
 changes={}
 for p in (root/'.github/workflows').glob('*.yml'):
  s=p.read_text();t=s.replace('LTS_MOBILE_RELEASE: v417','LTS_MOBILE_RELEASE: v421').replace('LTS_MOBILE_RELEASE=v417','LTS_MOBILE_RELEASE=v421')
  if p.name=='pages.yml':
   t=t.replace("paths: ['releases/v417/**'","paths: ['releases/v421/**','releases/v417/**'")
   t=t.replace('lts_v417_verify_published.cjs','lts_v421_verify_published.cjs').replace('v417-published-verification','v421-published-verification').replace('Verify published V417','Verify published V421')
   needle='      - name: Configure Pages'
   assert needle in t
   if 'node .github/scripts/lts_v421_release_contract.cjs' not in t:t=t.replace(needle,'          node .github/scripts/lts_v421_release_contract.cjs\n'+needle)
  if t!=s:changes[str(p.relative_to(root))]=t
 s=(root/'.github/scripts/lts_v417_verify_published.cjs').read_text()
 s=s.replace("['v417','v415'","['v421','v417','v415'").replace("{release:'v417',entry:'../releases/v417/app.html'}","{release:'v421',entry:'../releases/v421/app.html'}").replace('v417-published-verification','v421-published-verification').replace("ui:'v417'","ui:'v421'").replace("previous_ui:['v415'","previous_ui:['v417','v415'")
 changes['.github/scripts/lts_v421_verify_published.cjs']=s
 p=root/'.github/scripts/lts_v412_projection_browser.cjs';s=p.read_text();old="const concise=new URL(f.url()).pathname.includes('/releases/v417/');"
 new="const concise=/\\/releases\\/v(?:417|421)\\//.test(new URL(f.url()).pathname);"
 assert s.count(old)==1 or new in s
 changes[str(p.relative_to(root))]=s.replace(old,new)
 p=root/'.github/scripts/lts_v385_browser.cjs';s=p.read_text()
 old="if(positive&&i===2){assert.match(await dl.innerText(),/Sem saldo negativo no período/);assert.deepEqual(times,[day]);assert.deepEqual(amounts,[money(0)]);assert.match(cover,/31\\/12\\/2027/);}"
 new="if(positive&&i===2){const full=new URL(frame.url()).pathname.includes('/releases/v421/');assert.match(await dl.innerText(),full?/Sem saldo negativo até 31\\/12\\/2031/:/Sem saldo negativo no período/);assert.deepEqual(times,[day]);assert.deepEqual(amounts,[money(0)]);assert.match(cover,full?/31\\/12\\/2031/:/31\\/12\\/2027/);}"
 assert s.count(old)==1 or new in s
 changes[str(p.relative_to(root))]=s.replace(old,new)
 changes['mobile/current.json']=json.dumps({'release':'v421','entry':'../releases/v421/app.html'},indent=2)+'\n'
 changes['.github/scripts/lts_v421_release_contract.cjs']="""'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='releases/v421',m=JSON.parse(fs.readFileSync(root+'/manifest.json'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v421');assert.equal(m.base_release,'v417');
for(const[n,h]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,n))),h,n);
assert.deepEqual(Object.keys(m.files).concat('manifest.json').sort(),fs.readdirSync(root).sort());
assert.equal(sha(fs.readFileSync('releases/v417/manifest.json')),m.protected_manifest.sha256);
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v421',entry:'../releases/v421/app.html'});
const app=fs.readFileSync(root+'/app.html','utf8');assert(app.indexOf('<script src=\"lts-v421-scenario-model.js\"')<app.indexOf('<script src=\"lts-v384-startup-1.js\"'));
console.log(JSON.stringify({passed:true,release:'v421',assets:Object.keys(m.files).length,predecessor_unchanged:true}));
"""
 for name,s in changes.items():
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
  dest=out/'promotion'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s)
 # Replay the unchanged historical static gates with only the intended entry
 # version changed. Browser assertions remain in the final-commit workflows.
 text=(root/'.github/workflows/pages.yml').read_text()
 marker='      - name: Verify release assets and protected history\n        run: |\n'
 assert marker in text
 block=text.split(marker,1)[1].split('      - name: Configure Pages',1)[0]
 commands=textwrap.dedent(block);assert commands.count('node .github/scripts/')>=70
 result=subprocess.run(['bash','-euo','pipefail','-c',commands],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/'promotion-static-gates.txt').write_text(result.stdout);assert result.returncode==0,result.stdout[-3000:]
 return sorted(changes)
