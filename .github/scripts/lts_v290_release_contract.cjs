'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v290'),base=path.resolve('releases/v285'),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(manifest.release,'v290');assert.equal(manifest.base_release,'v285');
assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(manifest.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(manifest.files)){assert.equal(path.basename(name),name);assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,'Release asset '+name);}
for(const [name,hash]of Object.entries(manifest.protected))assert.equal(sha(fs.readFileSync(name)),hash,'Protected byte '+name);
assert.equal(sha(fs.readFileSync(path.join(root,'index.html'))),sha(fs.readFileSync(path.join(base,'index.html'))),'Base application remains unchanged');
const allowed=['app.html','manifest.json','provenance.json','lts-category-registry.js','lts-v290-usability.js','lts-v290-source-details.js','lts-v181-regression-closure.js','lts-v225-open-finance.js','lts-v225-consolidated.css','lts-v226-card-composition.js','lts-v228-bank-flow.js','lts-v183-award-provenance.js','lts-v183-card-period-candidate.js'];
const changed=fs.readdirSync(root).filter(name=>!fs.existsSync(path.join(base,name))||sha(fs.readFileSync(path.join(base,name)))!==sha(fs.readFileSync(path.join(root,name)))).sort();
assert.deepEqual(changed,allowed.sort(),'Bounded V290 UI scope');
for(const file of ['app.html','index.html'])for(const [,src]of fs.readFileSync(path.join(root,file),'utf8').matchAll(/<script\b[^>]*\bsrc="([^"]+)"/g)){assert(!/^https?:/.test(src));assert(fs.existsSync(path.resolve(root,src.split('?')[0])),'Missing '+src);}
for(const file of fs.readdirSync(root).filter(n=>n.endsWith('.js')))cp.execFileSync(process.execPath,['--check',path.join(root,file)],{stdio:'pipe'});
cp.execFileSync(process.execPath,['.github/scripts/lts_v285_release_contract.cjs'],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v290',files:fs.readdirSync(root).length,changed,index_unchanged:true,protected_bytes:true}));
