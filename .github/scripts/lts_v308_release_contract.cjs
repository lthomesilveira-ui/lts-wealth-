'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v308'),base=path.resolve('releases/v296'),m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v308');assert.equal(m.version,'v308');assert.equal(m.base_release,'v296');
assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files)){assert.equal(path.basename(name),name);assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);}
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,'Protected '+name);
const changed=fs.readdirSync(root).filter(n=>!fs.existsSync(path.join(base,n))||sha(fs.readFileSync(path.join(root,n)))!==sha(fs.readFileSync(path.join(base,n)))).sort();
assert.deepEqual(changed,['app.html','lts-v308-review-layout.js','manifest.json','provenance.json'].sort());
assert.equal(sha(fs.readFileSync(path.join(root,'index.html'))),sha(fs.readFileSync(path.join(base,'index.html'))));
for(const n of fs.readdirSync(root).filter(n=>n.endsWith('.js')))cp.execFileSync(process.execPath,['--check',path.join(root,n)],{stdio:'pipe'});
cp.execFileSync(process.execPath,['.github/scripts/lts_v296_release_contract.cjs'],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v308',changed,files:fs.readdirSync(root).length,protected_bytes:true,financial_source_writes:false}));
