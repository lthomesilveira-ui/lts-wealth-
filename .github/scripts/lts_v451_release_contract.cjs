'use strict';const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),base='releases/v450/',root='releases/v451/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v451');assert.equal(m.base_release,'v450');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
const changed=['app.html','lts-v227-read-transport.js','lts-v384-startup-1.js','lts-v384-startup-2.js','lts-v181-regression-closure.js','lts-v225-open-finance.js','provenance.json'];assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
for(const[n,h]of Object.entries(prior.files)){assert.equal(hash(base+n),h);if(!changed.includes(n))assert.equal(hash(root+n),h,'Preserved '+n)}
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n})}
for(const bundle of ['lts-v384-startup-1.js','lts-v384-startup-2.js']){
 let expected=fs.readFileSync(base+bundle,'utf8');
 for(const name of ['lts-v227-read-transport.js','lts-v181-regression-closure.js','lts-v225-open-finance.js']){
  const before=fs.readFileSync(base+name,'utf8'),after=fs.readFileSync(root+name,'utf8');
  if(expected.includes(before)){assert.equal(expected.split(before).length,2);expected=expected.replace(before,after);}
 }
 assert.equal(fs.readFileSync(root+bundle,'utf8'),expected,'Only the declared read recovery changes in '+bundle);
}
const current=process.env.LTS_MOBILE_RELEASE||'v442';assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:current,entry:'../releases/'+current+'/app.html'});
console.log(JSON.stringify({pass:true,release:'v451',assets:Object.keys(m.files).length,protected_base:'v450',financial_payload_and_source_guards_unchanged:true,canonical:current}));
