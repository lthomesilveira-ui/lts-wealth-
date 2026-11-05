'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base='releases/v411',root='releases/v412',runtime='lts-v412-projection-policy.js';
const oldHorizon="+4)+'-12-31'",newHorizon="+(window.__LTS_V412_PROJECTION?.model?5:4))+'-12-31'";
const oldForecast="p_to:(year+1)+'-12-31'",newForecast="p_to:(year+(window.__LTS_V412_PROJECTION?.model?5:1))+'-12-31'";
const oldExport='cachedFlow,refresh:options=>';
const newExport="cachedFlow,refreshForecast:async()=>{syncCashContext();if(state.forecast.status==='loading')await state.forecast.waiting;syncCashContext();if(!D||N.classList.contains('hidden'))return;return loadForecast(true)},refresh:options=>";
const legacyPatches=[
 {file:'lts-v183-v168-feedback-safe.js',horizon_sites:5,forecast_sites:0,export_sites:0},
 {file:'lts-v384-startup-1.js',horizon_sites:10,forecast_sites:1,export_sites:1},
 {file:'lts-v179-cash-recovery.js',horizon_sites:0,forecast_sites:1,export_sites:1}
];
const read=(dir,name)=>fs.readFileSync(dir+'/'+name,'utf8'),hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const manifest=JSON.parse(read(root,'manifest.json')),provenance=JSON.parse(read(root,'provenance.json'));
assert.equal(manifest.release,'v412');assert.equal(manifest.base_release,'v411');assert.equal(manifest.entry,'app.html');
assert.deepEqual([...Object.keys(manifest.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
assert.deepEqual(Object.keys(provenance.protected_base_files).sort(),fs.readdirSync(base).sort());
for(const[name,expected]of Object.entries(manifest.files))assert.equal(hash(root+'/'+name),expected,'release '+name);
for(const[name,expected]of Object.entries(provenance.protected_base_files))assert.equal(hash(base+'/'+name),expected,'immutable V411 '+name);
assert.equal(manifest.protected_manifest.path,base+'/manifest.json');assert.equal(hash(manifest.protected_manifest.path),manifest.protected_manifest.sha256);
assert.deepEqual(fs.readdirSync(root).sort(),[...fs.readdirSync(base),runtime].sort(),'one additive runtime');
for(const name of fs.readdirSync(base))if(!['app.html','manifest.json','provenance.json',...legacyPatches.map(x=>x.file)].includes(name))assert.equal(hash(root+'/'+name),hash(base+'/'+name),'preserved runtime '+name);
for(const patch of legacyPatches){
 const original=read(base,patch.file);
 assert.equal(original.split(oldHorizon).length-1,patch.horizon_sites);
 assert.equal(original.split(oldForecast).length-1,patch.forecast_sites);
 assert.equal(original.split(oldExport).length-1,patch.export_sites);
 const patched=original.replaceAll(oldHorizon,newHorizon).replaceAll(oldForecast,newForecast).replaceAll(oldExport,newExport);
 assert.equal(read(root,patch.file),patched,'only reviewed horizon/forecast sites may change in '+patch.file);
}
assert.deepEqual(provenance.legacy_runtime_patches,legacyPatches);
let expected=read(base,'app.html').replaceAll('V411','V412').replace('v411-rsu-policy-20261104','v412-projection-policy-20261104');
expected=expected.replace('</body>','<script src="'+runtime+'"></script>\n</body>');
assert.equal(read(root,'app.html'),expected);assert.equal(hash(root+'/'+runtime),hash(runtime));
const mobileRelease=process.env.LTS_MOBILE_RELEASE||'v412';
assert.deepEqual(JSON.parse(read('mobile','current.json')),{release:mobileRelease,entry:'../releases/'+mobileRelease+'/app.html'});
for(const key of['financial_event_writers_added','received_financial_payloads_modified','client_recalculates_financial_totals','historical_payments_created','private_http_validated','physical_mobile_validated'])assert.equal(provenance[key],false,key);
for(const key of['values_calculated_server_side','card_budget_is_total_floor','partial_history_preserves_last_complete_reference','prior_rsu_policy_preserved'])assert.equal(provenance[key],true,key);
console.log(JSON.stringify({pass:true,release:'v412',assets:fs.readdirSync(root).length,immutable_v411:true,financial_event_writers_added:false}));
