'use strict';
// Exercise the unchanged historical refresh scenarios against the selected UI.
// V421 deliberately normalizes a cached slice's from/to to its actual days;
// keep all amount, row, identity, failure, recovery and logout assertions.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const filename=path.join(__dirname,'lts_v415_refresh_browser.cjs');
let source=fs.readFileSync(filename,'utf8');
const bytes=Buffer.from(source),sha=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+bytes.length+'\0'),bytes])).digest('hex');
assert.equal(sha,'4682bdde860386f8d6453e6ad082e5bf08aa2509','review the adapter when the original suite changes');
const release=process.env.LTS_MOBILE_RELEASE||'v415';assert.match(release,/^v[0-9]+$/);
const pointer=JSON.parse(fs.readFileSync(path.join(__dirname,'../../mobile/current.json'),'utf8'));
assert.deepEqual(pointer,{release,entry:'../releases/'+release+'/app.html'});
const previous='/releases/v415/index.html';assert.equal(source.split(previous).length,2,'exactly one initializing-frame target');
source=source.replace(previous,'/releases/'+release+'/index.html');
if(release==='v421'){
 const old="assert.deepEqual({ from: before.current_future.from, to: before.current_future.to }, { from: '2026-10-31', to: '2031-12-31' }, 'Explicit preserved legacy source coverage');";
 const replacement="assert.deepEqual({ from: before.current_future.from, to: before.current_future.to }, { from: '2027-01-01', to: '2027-01-31' }, 'Cached slice declares the same explicit period as its validated daily rows');";
 assert.equal(source.split(old).length,2,'exactly one legacy coverage assertion');
 source=source.replace(old,replacement);
 const api=require(path.join(__dirname,'../../releases/v421/lts-v421-scenario-model.js'));
 const original={flow:{current_future:{from:'2026-10-31',to:'2031-12-31',days:[{date:'2027-01-01',balance:17}],events:[{date:'2027-01-01',amount:5}]}}};
 const snapshot=JSON.stringify(original),normalized=api.normalize(original,'2027-01-01','2027-01-31');
 assert.equal(JSON.stringify(original),snapshot,'original response is not mutated');
 assert.strictEqual(normalized.flow.current_future.days,original.flow.current_future.days,'all financial days retained verbatim');
 assert.strictEqual(normalized.flow.current_future.events,original.flow.current_future.events,'all movements retained verbatim');
 assert.deepEqual({from:normalized.flow.current_future.from,to:normalized.flow.current_future.to},{from:'2027-01-01',to:'2027-01-31'});
}
console.log(JSON.stringify({suite:'v415-durable-refresh',mobile_release:release,financial_assertions_preserved:true,selected_period_metadata_checked:release==='v421',production_files_modified:false}));
module._compile(source,filename);
