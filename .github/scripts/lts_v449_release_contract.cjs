'use strict';const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),base='releases/v448/',root='releases/v449/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v449');assert.equal(m.base_release,'v448');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
const changed=['app.html','lts-v227-read-transport.js','lts-v384-startup-1.js','lts-v415-product-refresh.js','provenance.json'];assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
for(const[n,h]of Object.entries(prior.files)){assert.equal(hash(base+n),h);if(!changed.includes(n))assert.equal(hash(root+n),h,'Preserved '+n)}
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n})}
const oldTransport=fs.readFileSync(base+'lts-v227-read-transport.js','utf8'),newTransport=fs.readFileSync(root+'lts-v227-read-transport.js','utf8');
const oldBundle=fs.readFileSync(base+'lts-v384-startup-1.js','utf8'),newBundle=fs.readFileSync(root+'lts-v384-startup-1.js','utf8');
assert.equal(oldBundle.split(oldTransport).length,2,'Exactly one actual bundled transport');
assert.equal(newBundle,oldBundle.replace(oldTransport,newTransport),'All bundled financial code is unchanged');
const current=process.env.LTS_MOBILE_RELEASE||'v442';assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:current,entry:'../releases/'+current+'/app.html'});
console.log(JSON.stringify({pass:true,release:'v449',assets:Object.keys(m.files).length,protected_base:'v448',financial_payload_and_source_guards_unchanged:true,canonical:current}));
