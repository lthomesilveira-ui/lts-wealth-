"""Prepare exact promotion files and run all protected static gates; no refs."""
from pathlib import Path
import json,subprocess,textwrap,hashlib

def prepare(root:Path,out:Path):
 changes={}
 def put(name,text):
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True)
  if p.exists() and p.read_text()==text:return
  p.write_text(text);changes[name]=text
 def replace(name,old,new):
  s=(root/name).read_text();assert old in s or new in s,(name,old[:80]);put(name,s.replace(old,new))
 for p in (root/'.github/workflows').glob('*.yml'):
  s=p.read_text();t=s.replace('LTS_MOBILE_RELEASE: v423','LTS_MOBILE_RELEASE: v425').replace('LTS_MOBILE_RELEASE=v423','LTS_MOBILE_RELEASE=v425')
  if p.name=='pages.yml':
   t=t.replace("paths: ['releases/v423/**'","paths: ['releases/v425/**','releases/v423/**'")
   t=t.replace('lts_v423_verify_published.cjs','lts_v425_verify_published.cjs').replace('v423-published-verification','v425-published-verification').replace('Verify published V423','Verify published V425')
   t=t.replace('          node .github/scripts/lts_v423_release_contract.cjs','          LTS_MOBILE_RELEASE=v425 node .github/scripts/lts_v423_release_contract.cjs')
   marker='      - name: Configure Pages';assert marker in t
   if 'node .github/scripts/lts_v425_release_contract.cjs' not in t:t=t.replace(marker,'          node .github/scripts/lts_v425_release_contract.cjs\n'+marker)
  if p.name=='v423-expense-clarity.yml':
   old='      - name: Stage generic release objects without updating refs\n        env:\n          GITHUB_TOKEN: ${{ github.token }}\n          REVIEWED_HEAD: ${{ github.event.pull_request.head.sha }}\n        run: python3 backend/tools/expense_clarity_v423/stage.py'
   new='      - name: Verify current gates without rewinding historical routing\n        run: python3 backend/tools/report_presentation_v417/read_only_gates.py > qa/v423/current-static-gates.txt'
   assert old in t or new in t;t=t.replace(old,new).replace('    permissions:\n      contents: write\n','')
  put(str(p.relative_to(root)),t)
 replace('.github/scripts/lts_v423_release_contract.cjs',
  "assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v423',entry:'../releases/v423/app.html'});",
  "const entry=process.env.LTS_MOBILE_RELEASE||'v423';assert.match(entry,/^v[0-9]+$/);assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:entry,entry:'../releases/'+entry+'/app.html'});")
 # Preserve all existing monetary, authorization and historical assertions.
 # Only their user interactions follow the newly approved Options hierarchy.
 helper="\nasync function showFlowOptions(f){const t=f.locator('.v425-options');if(await t.count()&&await t.getAttribute('open')===null)await t.locator(':scope>summary').click();}\n"
 for name in ['lts_v402_browser.cjs','lts_v411_rsu_browser.cjs','lts_v412_projection_browser.cjs']:
  path='.github/scripts/'+name;s=(root/path).read_text()
  if helper not in s:s=s.replace('async function run(',helper+'async function run(',1)
  if name=='lts_v402_browser.cjs':
   old="  const box=f.locator('#v402-d01-origin'),before=hash(await f.evaluate(()=>FLOWQ));"
   new="  await showFlowOptions(f);\n"+old
   if new not in s:assert old in s;s=s.replace(old,new)
  if name=='lts_v411_rsu_browser.cjs':
   old="  const basis=f.locator('[data-v411-flow-policy]');"
   new="  await showFlowOptions(f);\n"+old
   if new not in s:assert old in s;s=s.replace(old,new)
  if name=='lts_v412_projection_browser.cjs':
   s=s.replace('v(?:417|421|423)','v(?:417|421|423|425)')
   old="  await go(f,'Fluxo Diário');const panel=()=>f.locator('[data-v412-policy=\"flow\"]');"
   new=old+"\n  const optionsLayout=new URL(f.url()).pathname.includes('/releases/v425/');"
   if new not in s:assert old in s;s=s.replace(old,new)
   old="assert.match(await panel().innerText(),/Projeções até 31\\/12\\/2031/);assert.equal(await panel().locator('details').getAttribute('open'),null);"
   new="if(optionsLayout){assert.equal(await panel().isVisible(),false);assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model.horizon),'2031-12-31');}else assert.match(await panel().innerText(),/Projeções até 31\\/12\\/2031/);assert.equal(await panel().locator('details').getAttribute('open'),null);"
   if new not in s:assert old in s;s=s.replace(old,new)
   old="assert(closed.buttons.every(b=>b.x>=0&&b.right<=width+2&&b.height>=40));"
   new="if(optionsLayout)assert(closed.buttons.every(b=>b.height===0),'secondary controls stay outside default report');else "+old
   if new not in s:assert old in s;s=s.replace(old,new)
   s=s.replace("await panel().locator('summary').click();","await showFlowOptions(f);await panel().locator('summary').click();") if 'await showFlowOptions(f);await panel()' not in s else s
   old="  await panel().locator('[data-v412-refresh]').click();"
   new="  await showFlowOptions(f);\n"+old
   if new not in s:assert old in s;s=s.replace(old,new)
  put(path,s)
 # Existing adapter guards must be renewed only for the reviewed test text.
 name='.github/scripts/lts_v385_browser.cjs';s=(root/name).read_text();s=s.replace('v(?:421|423)','v(?:421|423|425)');put(name,s)
 data=s.encode();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 name='.github/scripts/lts_v385_current_entry.cjs';s=(root/name).read_text().replace('313cf57f091f62269781735cb4d6583512b059d8',blob)
 s=s.replace("new URL(f.url()).pathname.includes('/releases/v423/')","/\\/releases\\/v(?:423|425)\\//.test(new URL(f.url()).pathname)");put(name,s)
 name='.github/scripts/lts_v415_refresh_current_entry.cjs';s=(root/name).read_text().replace("['v421','v423']","['v421','v423','v425']")
 adapter="""
if(release==='v425'){
 const action="    await f.locator('[data-v412-policy=\\\"flow\\\"] [data-v412-refresh]').click();";
 const navigation="    const options=f.locator('.v425-options');if(await options.count()&&await options.getAttribute('open')===null)await options.locator(':scope>summary').click();\\n";
 assert.equal(source.split(action).length,2,'original manual refresh action retained exactly once');
 source=source.replace(action,navigation+action);
}
"""
 if adapter not in s:s=s.replace('module._compile(source,filename);',adapter+'module._compile(source,filename);')
 put(name,s)
 s=(root/'.github/scripts/lts_v423_verify_published.cjs').read_text().replace("['v423','v421'","['v425','v423','v421'").replace("{release:'v423',entry:'../releases/v423/app.html'}","{release:'v425',entry:'../releases/v425/app.html'}").replace('v423-published-verification','v425-published-verification').replace("ui:'v423'","ui:'v425'").replace("previous_ui:['v421'","previous_ui:['v423','v421'")
 put('.github/scripts/lts_v425_verify_published.cjs',s)
 put('mobile/current.json',json.dumps({'release':'v425','entry':'../releases/v425/app.html'},indent=2)+'\n')
 contract="""'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='releases/v425',m=JSON.parse(fs.readFileSync(root+'/manifest.json')),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v425');assert.equal(m.base_release,'v423');
for(const[n,h]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,n))),h,n);
assert.deepEqual(Object.keys(m.files).concat('manifest.json').sort(),fs.readdirSync(root).sort());
assert.equal(sha(fs.readFileSync('releases/v423/manifest.json')),m.protected_manifest.sha256);
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v425',entry:'../releases/v425/app.html'});
const app=fs.readFileSync(root+'/app.html','utf8');assert(app.indexOf('<script src="lts-v425-flow-options.js"')>app.indexOf('<script src="lts-v423-clarity.js"'));
assert(app.includes('V425'));console.log(JSON.stringify({pass:true,release:'v425',assets:Object.keys(m.files).length,predecessor_unchanged:true}));
"""
 put('.github/scripts/lts_v425_release_contract.cjs',contract)
 for name in ['AGENTS.md','UX_ACCEPTANCE.md']:
  s=(root/name).read_text();note='\n## Flow options hierarchy\n\nRead `UX_FLOW_OPTIONS.md` before editing Flow. Standalone collapsed premise/source panels still clutter the main report. Use the existing Options control, preserve material warnings and verify rendered default/open states.\n'
  if 'Read `UX_FLOW_OPTIONS.md`' not in s:put(name,s+note)
 text=(root/'.github/workflows/pages.yml').read_text();marker='      - name: Verify release assets and protected history\n        run: |\n';assert marker in text
 commands=textwrap.dedent(text.split(marker,1)[1].split('      - name: Configure Pages',1)[0]);assert commands.count('node .github/scripts/')>=70
 result=subprocess.run(['bash','-euo','pipefail','-c',commands],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/'promotion-static-gates.txt').write_text(result.stdout);assert result.returncode==0,result.stdout[-3000:]
 for name,text in changes.items():
  dest=out/'promotion'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
 return sorted(changes)
