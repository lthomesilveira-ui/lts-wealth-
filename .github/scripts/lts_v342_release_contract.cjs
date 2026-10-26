'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v342'),base=path.resolve('releases/v341'),read=(r,n)=>fs.readFileSync(path.join(r,n),'utf8'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v342');assert.equal(m.version,'v342');assert.equal(m.base_release,'v341');
assert.equal(fs.readdirSync(root).length,77);assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,name);
assert.equal(Object.keys(p.protected_base_files).length,77);
for(const [name,hash]of Object.entries(p.protected_base_files))assert.equal(sha(fs.readFileSync(path.join(base,name))),hash,'Immutable base '+name);
const changed=fs.readdirSync(root).filter(n=>read(root,n)!==read(base,n)).sort();
assert.deepEqual(changed,['app.html','lts-v337-month-overview.js','manifest.json','provenance.json'].sort());
assert.equal(read(root,'app.html'),read(base,'app.html').replaceAll('V341','V342').replace('v341-bank-collection-20261025','v342-month-rollover-20261026'));
let expected=read(base,'lts-v337-month-overview.js');
for(const [old,next]of [
 ["month:'',sequence:0","month:'',followCurrentMonth:true,sequence:0"],
 ["   if(!state.month)state.month=today().slice(0,7);","   if(!state.month||state.followCurrentMonth)state.month=businessDay.slice(0,7);"],
 ["state.month=control.value;state.sequence++","state.month=control.value;state.followCurrentMonth=!control.value||control.value===today().slice(0,7);state.sequence++"],
 ["state.owner=null;state.month='';state.sequence++","state.owner=null;state.month='';state.followCurrentMonth=true;state.sequence++"]
]){assert.equal(expected.split(old).length,2,'Unique base anchor: '+old);expected=expected.replace(old,next);}
assert.equal(read(root,'lts-v337-month-overview.js'),expected,'Only the month-following state changes');
assert.equal(p.frontend_only,true);assert.equal(p.backend_changed,false);assert.equal(p.financial_source_data_changed,false);
assert.equal(p.physical_mobile_validated,false);assert.equal(p.private_http_validated,false);
assert.deepEqual(p.runtime_changes,['lts-v337-month-overview.js']);assert.equal(p.boot_registrations.length,32);
cp.execFileSync(process.execPath,['--check',path.join(root,'lts-v337-month-overview.js')],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v342',files:77,changed_runtime_assets:1,unchanged_other_runtime_assets:true,monthly_calculations_exact:true,financial_code_outside_month_selection_exact:true,read_deadlines_exact:true,immutable_base_files:77,backend_changed:false}));
