'use strict';const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),base='releases/v440/',root='releases/v441/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v441');assert.equal(m.base_release,'v440');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
const changed=['app.html','index.html','lts-v227-read-transport.js','lts-v384-read-priority.js','lts-v384-startup-1.js','lts-v415-product-refresh.js','provenance.json'];
for(const[name,h]of Object.entries(prior.files)){assert.equal(hash(base+name),h);if(!changed.includes(name))assert.equal(hash(root+name),h,'Preserved '+name);}
for(const[name,h]of Object.entries(m.files)){assert.equal(hash(root+name),h);if(name.endsWith('.js'))new vm.Script(fs.readFileSync(root+name,'utf8'),{filename:name});}
for(const name of ['app.html','index.html'])for(const match of fs.readFileSync(root+name,'utf8').matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi))new vm.Script(match[1]);
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v441',entry:'../releases/v441/app.html'});
assert.equal(m.files['lts-v412-projection-policy.js'],prior.files['lts-v412-projection-policy.js'],'Dated Aeternum provisions unchanged');
const p=JSON.parse(fs.readFileSync(root+'provenance.json'));assert.equal(p.provision_policy_changed,false);assert.equal(p.existing_financial_writers_changed,false);
const source=fs.readFileSync(root+'lts-v384-startup-1.js','utf8');for(const n of ['lts-v227-read-transport.js','lts-v384-read-priority.js'])assert(source.includes(fs.readFileSync(root+n,'utf8').trim()),'Actual bundle contains '+n);
console.log(JSON.stringify({pass:true,release:'v441',assets:Object.keys(m.files).length,protected_base:'v440',dated_provisions_unchanged:true}));
