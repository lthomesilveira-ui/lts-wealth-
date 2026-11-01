'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base='releases/v391',root='releases/v393',read=(p,n)=>fs.readFileSync(p+'/'+n,'utf8'),hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v393');assert.equal(m.base_release,'v391');
for(const[n,h]of Object.entries(m.files))assert.equal(hash(root+'/'+n),h,n);
for(const[n,h]of Object.entries(m.protected))assert.equal(hash(n),h,n);
for(const[n,h]of Object.entries(p.protected_base_files))assert.equal(hash(base+'/'+n),h,n);
assert.deepEqual(fs.readdirSync(root).sort(),fs.readdirSync(base).sort());
assert.deepEqual(fs.readdirSync(root).filter(n=>hash(root+'/'+n)!==hash(base+'/'+n)).sort(),[...p.runtime_changes,'manifest.json','provenance.json'].sort());
for(const[bundle,names]of Object.entries({'lts-v384-startup-1.js':['lts-v227-read-transport.js'],'lts-v384-startup-2.js':['lts-v337-month-model.js','lts-v337-month-overview.js']})){
 let expected=read(base,bundle);for(const n of names){assert(expected.includes(read(base,n)));expected=expected.replace(read(base,n),read(root,n));}assert.equal(read(root,bundle),expected);
}
for(const n of ['lts-v226-card-composition.js','lts-property-reconciliation-model.js','lts-v382-flow-layout.js','lts-v333-actions-model.js'])assert.equal(hash(root+'/'+n),hash(base+'/'+n),'closed financial functionality '+n);
const model=require('../../'+root+'/lts-v337-month-model.js');
assert.deepEqual(model.monthBounds('2026-11','2026-11-01'),{from:'2026-11-01',to:'2026-11-30',months:['2026-11'],partial:true,month:'2026-11'});
assert.equal(model.monthBounds('2032-01','2026-11-01'),null);assert.equal(model.monthBounds('2026-13','2026-11-01'),null);
assert.deepEqual(model.monthBounds('2028-02','2026-11-01').to,'2028-02-29');
assert(model.forecastPeriodBounds('2026-11-01','2027-01-31','2026-11-01'));
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v393',entry:'../releases/v393/app.html'});
assert.equal(p.financial_source_data_changed,false);assert.equal(p.private_http_validated,false);assert.equal(p.physical_mobile_validated,false);
console.log(JSON.stringify({pass:true,release:'v393',full_calendar_month:true,immutable_previous_releases:true,closed_functionality_exact:true,no_financial_source_writes:true}));
