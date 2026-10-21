'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v293'),base=path.resolve('releases/v291'),m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(m.release,'v293');assert.equal(m.version,'v293');assert.equal(m.base_release,'v291');
assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files)){assert.equal(path.basename(name),name);assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);}
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,'Protected '+name);
const changed=fs.readdirSync(root).filter(n=>sha(fs.readFileSync(path.join(root,n)))!==sha(fs.readFileSync(path.join(base,n)))).sort();
assert.deepEqual(changed,['app.html','lts-v290-source-details.js','manifest.json','provenance.json'].sort());
assert.equal(sha(fs.readFileSync(path.join(root,'index.html'))),sha(fs.readFileSync(path.join(base,'index.html'))));
const source=fs.readFileSync(path.join(root,'lts-v290-source-details.js'),'utf8');
assert(source.includes("lts_browser_future_bank_v293"));
assert(source.includes('x.identity?.destination_bank===ACC'));
assert(source.includes('overdue_unconfirmed'));
assert(!source.includes('Elas ainda não alteram a projeção por conta.'));
for(const n of fs.readdirSync(root).filter(n=>n.endsWith('.js')))cp.execFileSync(process.execPath,['--check',path.join(root,n)],{stdio:'pipe'});
cp.execFileSync(process.execPath,['.github/scripts/lts_v291_release_contract.cjs'],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v293',changed,files:fs.readdirSync(root).length,protected_bytes:true,historical_sources_preserved:true}));
