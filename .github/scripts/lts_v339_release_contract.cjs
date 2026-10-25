'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v339'),base=path.resolve('releases/v337'),m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),p=JSON.parse(fs.readFileSync(path.join(root,'provenance.json'))),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
assert.equal(m.release,'v339');assert.equal(m.version,'v339');assert.equal(m.base_release,'v337');assert.equal(fs.readdirSync(root).length,77);
assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,'Protected '+name);
assert.equal(p.boot_registrations.length,32);assert.equal(new Set(p.boot_registrations).size,32);
const changed=fs.readdirSync(root).filter(n=>!fs.existsSync(path.join(base,n))||sha(fs.readFileSync(path.join(root,n)))!==sha(fs.readFileSync(path.join(base,n)))).sort();
assert.deepEqual(changed,[...p.boot_registrations,'app.html','lts-v339-component-boot.js','manifest.json','provenance.json'].sort());
const anchors={'lts-v178-review-actions.js':' let generation=0;',
 'lts-v183-award-provenance.js':" const shell=document.getElementById('shell');let generation=0;",
 'lts-v183-card-payment-status.js':" const shell=document.getElementById('shell');let generation=0;",
 'lts-v275-overdue-visibility.js':"  const shell = document.getElementById('shell');"};
for(const name of p.boot_registrations){
 const old=fs.readFileSync(path.join(base,name),'utf8'),current=fs.readFileSync(path.join(root,name),'utf8'),registration=" window.LTSV339Boot?.watch('"+name+"',install);\n";
 assert.equal(current.split(registration).length,2,'One registration '+name);
 if(anchors[name]){assert(old.includes(anchors[name]));assert(current.startsWith(old.slice(0,old.indexOf(anchors[name]))),'Original financial runtime prefix '+name);}
 else assert.equal(current.replace(registration,''),old,'Only readiness registration added '+name);
}
assert.deepEqual(p.initializers_refactored.slice().sort(),Object.keys(anchors).sort());
const app=fs.readFileSync(path.join(root,'app.html'),'utf8');assert(app.indexOf('lts-v339-component-boot.js')<app.indexOf('lts-v227-read-transport.js'),'Coordinator is available before component scripts');
for(const name of fs.readdirSync(root).filter(x=>x.endsWith('.js')))cp.execFileSync(process.execPath,['--check',path.join(root,name)],{stdio:'pipe'});
cp.execFileSync(process.execPath,['.github/scripts/lts_v337_release_contract.cjs'],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v339',files:77,registered_components:32,financial_runtime_prefixes_exact:true,read_transport_and_core_exact:true,protected_releases_exact:true}));
