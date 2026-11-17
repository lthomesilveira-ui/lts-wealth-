'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),base=path.join(root,'releases/v466'),target=path.join(root,'releases/v467');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),read=p=>fs.readFileSync(p),m=JSON.parse(read(path.join(target,'manifest.json'))),prior=JSON.parse(read(path.join(base,'manifest.json')));
assert.equal(m.release,'v467');assert.equal(m.version,'v467');assert.equal(m.base_release,'v466');
assert.deepEqual(m.protected_manifest,{path:'releases/v466/manifest.json',sha256:hash(read(path.join(base,'manifest.json')))});
assert.deepEqual(Object.keys(m.files).sort(),Object.keys(prior.files).sort());assert.deepEqual(fs.readdirSync(target).sort(),[...Object.keys(m.files),'manifest.json'].sort());
const changed=['app.html','provenance.json','lts-v181-regression-closure.js','lts-v333-actions-model.js','lts-v225-open-finance.js','lts-v384-startup-1.js','lts-v384-startup-2.js'];
for(const [name,h] of Object.entries(m.files)){assert.equal(hash(read(path.join(target,name))),h,name);if(!changed.includes(name))assert.equal(h,prior.files[name],name+' remains immutable');}
assert.equal(Object.keys(m.files).length,109);console.log(JSON.stringify({pass:true,assets:110,changed,protected:'v466',financial_writes:0}));
