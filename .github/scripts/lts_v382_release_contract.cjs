'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='releases/v382',base='releases/v379',read=(d,n)=>fs.readFileSync(d+'/'+n,'utf8');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v382');assert.equal(m.base_release,'v379');
for(const[n,h]of Object.entries(m.files))assert.equal(sha(root+'/'+n),h,n);
for(const[n,h]of Object.entries(m.protected))assert.equal(sha(n),h,n);
for(const[n,h]of Object.entries(p.protected_base_files))assert.equal(sha(base+'/'+n),h,n);
const changed=fs.readdirSync(root).filter(n=>!fs.existsSync(base+'/'+n)||sha(root+'/'+n)!==sha(base+'/'+n)).sort();
assert.deepEqual(changed,['app.html','lts-v382-flow-layout.css','lts-v382-flow-layout.js','lts-v172-v171-review.js','manifest.json','provenance.json'].sort());
assert.equal(read(root,'index.html'),read(base,'index.html'));
assert.equal(read(root,'app.html'),read(base,'app.html').replaceAll('V379','V382').replace('v379-expenses-period-20261029','v382-flow-layout-20261030').replace('</body>','<script src="lts-v382-flow-layout.js"></script>\n</body>'));
for(const n of fs.readdirSync(base).filter(n=>n.endsWith('.js')&&n!=='lts-v172-v171-review.js'))assert.equal(sha(root+'/'+n),sha(base+'/'+n),'existing JavaScript remains exact: '+n);
assert.equal(p.financial_source_data_changed,false);assert.equal(p.backend_changed,false);assert.equal(p.private_http_validated,false);assert.equal(p.physical_mobile_validated,false);
assert.deepEqual(JSON.parse(read('mobile','current.json')),{release:'v382',entry:'../releases/v382/app.html'});
assert.equal(JSON.parse(read('mobile','manifest.webmanifest')).id,'/lts-wealth-/mobile/');
const oldGuard="(V!=='Fluxo Diário'||!window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.initial_applied_at)";
const newGuard="(V!=='Fluxo Diário'||(!window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.initial_applied_at&&!window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action))";
assert.equal(read(root,'lts-v172-v171-review.js'),read(base,'lts-v172-v171-review.js').replace(oldGuard,newGuard),'only the explicit control exception changes in the inherited runtime');
const vm=require('node:vm'),predicate=source=>source.match(/if\((from===today\(\).*?)\)return Promise.resolve\(\);/)[1];
for(const [initial,explicit,view,blocked]of [[false,false,'Fluxo Diário',true],[false,true,'Fluxo Diário',false],[true,false,'Fluxo Diário',false],[false,true,'Dashboard',true]]){
 const context={from:'2026-10-30',to:'2026-11-28',today:()=> '2026-10-30',shift:()=> '2026-11-28',V:view,window:{__LTS_DASHBOARD_EXECUTIVE_STATUS:{initial_applied_at:initial?'actual-marker':undefined},__LTS_V382_FLOW_LAYOUT:{explicit_period_action:explicit}}};
 assert.equal(vm.runInNewContext(predicate(read(root,'lts-v172-v171-review.js')),context),blocked);
 if(!initial&&explicit&&view==='Fluxo Diário')assert.equal(vm.runInNewContext(predicate(read(base,'lts-v172-v171-review.js')),context),true,'negative control reproduces obsolete-marker suppression');
}
console.log(JSON.stringify({pass:true,release:'v382',existing_releases_exact:true,financial_readers_and_calculations_preserved:true,explicit_period_guard:true,automatic_bootstrap_guard_preserved:true,protected_root_exact:true,financial_writes:0}));
