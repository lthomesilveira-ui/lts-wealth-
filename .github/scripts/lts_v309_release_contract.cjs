'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v309'),base=path.resolve('releases/v308'),m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v309');assert.equal(m.version,'v309');assert.equal(m.base_release,'v308');
assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files)){assert.equal(path.basename(name),name);assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);}
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,'Protected '+name);
const changed=fs.readdirSync(root).filter(n=>sha(fs.readFileSync(path.join(root,n)))!==sha(fs.readFileSync(path.join(base,n)))).sort();
assert.deepEqual(changed,['app.html','lts-v183-v168-feedback-safe.js','lts-v183-wealth-debt-integrity.js','manifest.json','provenance.json'].sort());
for(const n of fs.readdirSync(root).filter(n=>n.endsWith('.js')))cp.execFileSync(process.execPath,['--check',path.join(root,n)],{stdio:'pipe'});
cp.execFileSync(process.execPath,['.github/scripts/lts_v308_release_contract.cjs'],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v309',changed,files:fs.readdirSync(root).length,protected_bytes:true,financial_source_writes:false}));
