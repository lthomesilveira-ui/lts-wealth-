'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const base='releases/v442/',root='releases/v444/',prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v444');assert.equal(m.base_release,'v442');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
const changed=['app.html','lts-v227-read-transport.js','lts-v384-startup-1.js','lts-v415-product-refresh.js','provenance.json'];
assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
for(const[n,h]of Object.entries(prior.files)){assert.equal(hash(base+n),h,'Immutable V442 '+n);if(!changed.includes(n))assert.equal(hash(root+n),h,'Preserved '+n)}
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n})}
const source=fs.readFileSync(root+'lts-v384-startup-1.js','utf8');assert(source.includes(fs.readFileSync(root+'lts-v227-read-transport.js','utf8')));
const mobile=process.env.LTS_MOBILE_RELEASE||'v442';assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:mobile,entry:'../releases/'+mobile+'/app.html'});
assert.equal(hash(root+'index.html'),hash(base+'index.html'));
for(const n of['lts-v412-projection-policy.js','lts-v441-budget-model.js','lts-v441-budget-ui.js','lts-v384-startup-2.js'])assert.equal(hash(root+n),hash(base+n));
console.log(JSON.stringify({pass:true,release:'v444',assets:Object.keys(m.files).length,immutable_base:'v442',financial_payload_and_source_guards_unchanged:true,canonical:mobile}));
