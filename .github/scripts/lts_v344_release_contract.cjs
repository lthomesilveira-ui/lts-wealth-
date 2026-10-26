'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v344'),base=path.resolve('releases/v342'),read=(r,n)=>fs.readFileSync(path.join(r,n),'utf8'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v344');assert.equal(m.base_release,'v342');assert.equal(m.version,'v344');
assert.equal(fs.readdirSync(root).length,77);assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [n,h]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,n))),h,n);
for(const [n,h]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(n)),h,n);
assert.equal(Object.keys(p.protected_base_files).length,77);
for(const [n,h]of Object.entries(p.protected_base_files))assert.equal(sha(fs.readFileSync(path.join(base,n))),h,'Immutable V342 '+n);
assert.deepEqual(fs.readdirSync(root).filter(n=>read(root,n)!==read(base,n)).sort(),['app.html','lts-v179-cash-recovery.js','manifest.json','provenance.json'].sort());
assert.equal(read(root,'app.html'),read(base,'app.html').replaceAll('V342','V344').replace('v342-month-rollover-20261026','v344-expense-return-20261026'));
const old=read(base,'lts-v179-cash-recovery.js'),next=read(root,'lts-v179-cash-recovery.js');
const bounds=s=>[s.indexOf('  let sequence=0,lastFocus=null;'),s.indexOf('  function decorateFlow(){')];
const [oa,ob]=bounds(old),[na,nb]=bounds(next);assert(oa>=0&&ob>oa&&na>=0&&nb>na);
let normalized=next.slice(0,na)+old.slice(oa,ob)+next.slice(nb);
for(const [changed,original]of [
 ['render=function(){if(state.detail&&state.detail.route!==V)closeDetail();const out=previousRender();after();return out};','render=function(){const out=previousRender();after();return out};'],
 ["if(event==='SIGNED_IN'){closeDetail();cashAuthEpoch++;syncCashContext()}","if(event==='SIGNED_IN'){cashAuthEpoch++;syncCashContext()}"],
 ["window.addEventListener('lts:data-invalidated',()=>{\n   if(state.detail)closeDetail();","window.addEventListener('lts:data-invalidated',()=>{"]
]){assert.equal(normalized.split(changed).length,2);normalized=normalized.replace(changed,original);}
assert.equal(normalized,old,'All code outside detail navigation and stale-detail closure stays exact');
for(const guard of ['if(keys.has(row.key))','d.rows.length!==d.count','Math.abs(total(d.rows.map(x=>x.amount))-d.total)>0.02','if(token!==sequence)return','if(revision&&p.revision!==revision)'])assert(next.includes(guard),guard);
assert.equal(p.frontend_only,true);assert.equal(p.backend_changed,false);assert.equal(p.financial_source_data_changed,false);
assert.equal(p.private_http_validated,false);assert.equal(p.physical_mobile_validated,false);assert.deepEqual(p.runtime_changes,['lts-v179-cash-recovery.js']);assert.equal(p.boot_registrations.length,32);
cp.execFileSync(process.execPath,['--check',path.join(root,'lts-v179-cash-recovery.js')]);
console.log(JSON.stringify({pass:true,release:'v344',files:77,runtime_assets_changed:1,financial_code_outside_detail_navigation_exact:true,immutable_base_files:77,classification_reorganization:false}));
