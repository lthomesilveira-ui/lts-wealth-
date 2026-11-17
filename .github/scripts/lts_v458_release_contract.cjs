'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const base='releases/v454/',root='releases/v458/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),manifest=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(manifest.release,'v458');assert.equal(manifest.base_release,'v454');
assert.equal(manifest.protected_manifest.sha256,hash(base+'manifest.json'));
assert.deepEqual([...Object.keys(manifest.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
const components=['lts-v225-open-finance.js','lts-v415-product-refresh.js','lts-v227-read-transport.js'];
const changed=new Set(['app.html',...components,'lts-v384-startup-1.js','lts-v384-startup-2.js','provenance.json']);
for(const[name,expected]of Object.entries(prior.files)){
 assert.equal(hash(base+name),expected,'Protected predecessor '+name);
 if(!changed.has(name))assert.equal(hash(root+name),expected,'Unchanged application asset '+name);
}
for(const[name,expected]of Object.entries(manifest.files)){
 assert.equal(hash(root+name),expected,'Manifest '+name);
 if(name.endsWith('.js'))new vm.Script(fs.readFileSync(root+name,'utf8'),{filename:name});
}
for(const bundle of ['lts-v384-startup-1.js','lts-v384-startup-2.js']){
 let expected=fs.readFileSync(base+bundle,'utf8');
 for(const name of components){const before=fs.readFileSync(base+name,'utf8');if(expected.includes(before)){assert.equal(expected.split(before).length,2);expected=expected.replace(before,fs.readFileSync(root+name,'utf8'));}}
 assert.equal(fs.readFileSync(root+bundle,'utf8'),expected,'Declared refresh components only in '+bundle);
}
assert(fs.readFileSync(root+'app.html','utf8').includes('V458'));
console.log(JSON.stringify({pass:true,release:'v458',protected:'v454',assets:Object.keys(manifest.files).length,financial_functions_and_writers_preserved:true}));
