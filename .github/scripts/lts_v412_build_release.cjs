'use strict';
// Deterministic additive release; previously published bytes are immutable.
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base='releases/v411',target='releases/v412',runtime='lts-v412-projection-policy.js';
const oldHorizon="+4)+'-12-31'",newHorizon="+(window.__LTS_V412_PROJECTION?.model?5:4))+'-12-31'";
const oldForecast="p_to:(year+1)+'-12-31'",newForecast="p_to:(year+(window.__LTS_V412_PROJECTION?.model?5:1))+'-12-31'";
const oldExport='cachedFlow,refresh:options=>';
const newExport="cachedFlow,refreshForecast:async()=>{syncCashContext();if(state.forecast.status==='loading')await state.forecast.waiting;syncCashContext();if(!D||N.classList.contains('hidden'))return;return loadForecast(true)},refresh:options=>";
const legacyPatches=[
 {file:'lts-v183-v168-feedback-safe.js',horizon_sites:5,forecast_sites:0,export_sites:0},
 {file:'lts-v384-startup-1.js',horizon_sites:10,forecast_sites:1,export_sites:1},
 {file:'lts-v179-cash-recovery.js',horizon_sites:0,forecast_sites:1,export_sites:1}
];
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const prior=JSON.parse(fs.readFileSync(base+'/manifest.json','utf8'));
for(const[name,sha]of Object.entries(prior.files))assert.equal(hash(base+'/'+name),sha,'protected V411 '+name);
assert(fs.existsSync(runtime),'reviewed V412 runtime is required');
fs.mkdirSync(target,{recursive:true});
for(const name of fs.readdirSync(base))if(!['app.html','manifest.json','provenance.json'].includes(name))fs.copyFileSync(base+'/'+name,target+'/'+name);
for(const patch of legacyPatches){
 let value=fs.readFileSync(base+'/'+patch.file,'utf8');
 assert.equal(value.split(oldHorizon).length-1,patch.horizon_sites,patch.file+' reviewed horizon sites');
 assert.equal(value.split(oldForecast).length-1,patch.forecast_sites,patch.file+' reviewed forecast sites');
 assert.equal(value.split(oldExport).length-1,patch.export_sites,patch.file+' reviewed export sites');
 value=value.replaceAll(oldHorizon,newHorizon).replaceAll(oldForecast,newForecast).replaceAll(oldExport,newExport);
 fs.writeFileSync(target+'/'+patch.file,value);
}
fs.copyFileSync(runtime,target+'/'+runtime);
let app=fs.readFileSync(base+'/app.html','utf8').replaceAll('V411','V412').replace('v411-rsu-policy-20261104','v412-projection-policy-20261104');
app=app.replace('</body>','<script src="'+runtime+'"></script>\n</body>');
fs.writeFileSync(target+'/app.html',app);
const protectedFiles=Object.fromEntries(fs.readdirSync(base).sort().map(name=>[name,hash(base+'/'+name)]));
const provenance={release:'v412',base_release:'v411',candidate_only:false,
 scope:'Owner-authorized rolling five-year cash-flow projections with verified twelve-month references, recurring calendars and a manual refresh action.',
 protected_base_files:protectedFiles,financial_event_writers_added:false,received_financial_payloads_modified:false,
 values_calculated_server_side:true,client_recalculates_financial_totals:false,
 card_budget_is_total_floor:true,partial_history_preserves_last_complete_reference:true,
 historical_payments_created:false,prior_rsu_policy_preserved:true,
 legacy_runtime_patches:legacyPatches,
 legacy_runtime_patch_scope:'Reviewed default/chart horizon expressions and a forecast-only refresh method; earlier release bytes and the disabled-policy baseline remain intact.',
 private_http_validated:false,physical_mobile_validated:false,
 test_scope:'Fictional browser fixtures and PostgreSQL tests; private source audits and live database proofs remain outside the repository.'};
fs.writeFileSync(target+'/provenance.json',JSON.stringify(provenance,null,2)+'\n');
const files=Object.fromEntries(fs.readdirSync(target).filter(name=>name!=='manifest.json').sort().map(name=>[name,hash(target+'/'+name)]));
const manifest={release:'v412',base_release:'v411',entry:'app.html',files,protected_manifest:{path:base+'/manifest.json',sha256:hash(base+'/manifest.json')}};
fs.writeFileSync(target+'/manifest.json',JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync('mobile/current.json',JSON.stringify({release:'v412',entry:'../releases/v412/app.html'},null,2)+'\n');
console.log(JSON.stringify({pass:true,release:'v412',assets:fs.readdirSync(target).length,protected_base:'v411'}));
