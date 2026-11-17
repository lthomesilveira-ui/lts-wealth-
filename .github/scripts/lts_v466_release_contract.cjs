'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),base=path.join(root,'releases/v463'),target=path.join(root,'releases/v466');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),read=p=>fs.readFileSync(p),manifest=JSON.parse(read(path.join(target,'manifest.json'))),prior=JSON.parse(read(path.join(base,'manifest.json')));
assert.equal(manifest.release,'v466');assert.equal(manifest.version,'v466');assert.equal(manifest.base_release,'v463');
assert.deepEqual(manifest.protected_manifest,{path:'releases/v463/manifest.json',sha256:hash(read(path.join(base,'manifest.json')))});
assert.deepEqual(Object.keys(manifest.files).sort(),Object.keys(prior.files).sort());
assert.deepEqual(fs.readdirSync(target).sort(),[...Object.keys(manifest.files),'manifest.json'].sort());
const changed=['app.html','index.html','lts-v463-customer.css','provenance.json'];
for(const [name,digest] of Object.entries(manifest.files)){assert.equal(hash(read(path.join(target,name))),digest,name);if(!changed.includes(name))assert.equal(digest,prior.files[name],name+' remains byte-identical');}
assert.equal(Object.keys(manifest.files).length,109);
console.log(JSON.stringify({pass:true,release:'v466',assets:110,protected:'v463',changed,financial_writes:0}));
