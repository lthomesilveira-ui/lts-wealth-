'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const priorPath='releases/v436/',path='releases/v439/';
const prior=JSON.parse(fs.readFileSync(priorPath+'manifest.json')),next=JSON.parse(fs.readFileSync(path+'manifest.json'));
assert.equal(next.release,'v439');assert.equal(next.base_release,'v436');
assert.equal(next.protected_manifest.sha256,sha(fs.readFileSync(priorPath+'manifest.json')));
assert.deepEqual(Object.keys(next.files),Object.keys(prior.files));
assert.deepEqual([...Object.keys(next.files),'manifest.json'].sort(),fs.readdirSync(path).sort());
for(const[name,expected]of Object.entries(prior.files)){assert.equal(sha(fs.readFileSync(priorPath+name)),expected);assert.equal(sha(fs.readFileSync(path+name)),next.files[name]);}
assert.deepEqual(Object.keys(next.files).filter(name=>next.files[name]!==prior.files[name]).sort(),['app.html','lts-v181-regression-closure.js','lts-v384-startup-1.js','provenance.json']);
const provenance=JSON.parse(fs.readFileSync(path+'provenance.json'));
for(const key of ['financial_values_changed','mutation_paths_changed','query_arguments_changed','cache_or_auth_policy_changed'])assert.equal(provenance[key],false);
const script=fs.readFileSync(path+'lts-v181-regression-closure.js','utf8');
assert.equal(script.split("window.addEventListener('lts:card-classified',refreshReviewAfterCardClassification)").length,2);
assert(fs.readFileSync(path+'lts-v384-startup-1.js','utf8').includes(script.trim()));
console.log(JSON.stringify({pass:true,release:'v439',assets:Object.keys(next.files).length}));
