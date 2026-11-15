'use strict';const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),base='releases/v446/',root='releases/v447/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v447');assert.equal(m.base_release,'v446');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
const changed=['app.html','lts-v415-product-refresh.js','provenance.json'];assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
for(const[n,h]of Object.entries(prior.files)){assert.equal(hash(base+n),h);if(!changed.includes(n))assert.equal(hash(root+n),h,'Preserved '+n)}
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n})}
const current=process.env.LTS_MOBILE_RELEASE||'v442';assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:current,entry:'../releases/'+current+'/app.html'});
console.log(JSON.stringify({pass:true,release:'v447',assets:Object.keys(m.files).length,protected_base:'v446',financial_payload_and_source_guards_unchanged:true,canonical:current}));
