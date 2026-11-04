'use strict';
// Deterministic additive release. Published V407 bytes are never rewritten.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base='releases/v407',target='releases/v411',runtime='lts-v411-rsu-policy.js';
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const prior=JSON.parse(fs.readFileSync(base+'/manifest.json','utf8'));
for(const[name,sha]of Object.entries(prior.files))assert.equal(hash(base+'/'+name),sha,'protected V407 '+name);
assert(fs.existsSync(runtime),'reviewed V411 runtime is required');
fs.mkdirSync(target,{recursive:true});
for(const name of fs.readdirSync(base))if(!['app.html','manifest.json','provenance.json'].includes(name))fs.copyFileSync(base+'/'+name,target+'/'+name);
fs.copyFileSync(runtime,target+'/'+runtime);
let app=fs.readFileSync(base+'/app.html','utf8').replaceAll('V407','V411').replace('v407-wealth-documents-20261104','v411-rsu-policy-20261104');
app=app.replace('</body>','<script src="'+runtime+'"></script>\n</body>');
fs.writeFileSync(target+'/app.html',app);
const protectedFiles=Object.fromEntries(fs.readdirSync(base).sort().map(name=>[name,hash(base+'/'+name)]));
const provenance={release:'v411',base_release:'v407',candidate_only:false,
 scope:'Gross and estimated net RSU values, one planning reserve, and a conditional acquisition scenario with documented grant cohorts.',
 protected_base_files:protectedFiles,financial_event_writers_added:false,received_financial_payloads_modified:false,
 values_calculated_server_side:true,client_reapplies_net_factor:false,conditional_scenario_creates_dates:false,
 existing_quote_writers_preserved:true,grant_2026_calendar_preserved:true,private_http_validated:false,physical_mobile_validated:false,
 test_scope:'Fictional HTTP browser fixtures; private documentary and database proofs are retained outside the repository.'};
fs.writeFileSync(target+'/provenance.json',JSON.stringify(provenance,null,2)+'\n');
const files=Object.fromEntries(fs.readdirSync(target).filter(name=>name!=='manifest.json').sort().map(name=>[name,hash(target+'/'+name)]));
const manifest={release:'v411',base_release:'v407',entry:'app.html',files,protected_manifest:{path:base+'/manifest.json',sha256:hash(base+'/manifest.json')}};
fs.writeFileSync(target+'/manifest.json',JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync('mobile/current.json',JSON.stringify({release:'v411',entry:'../releases/v411/app.html'},null,2)+'\n');
console.log(JSON.stringify({pass:true,release:'v411',assets:fs.readdirSync(target).length,protected_base:'v407'}));
