'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const base='releases/v439/',release='releases/v440/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json'));
const next=JSON.parse(fs.readFileSync(release+'manifest.json'));
assert.equal(next.release,'v440');assert.equal(next.base_release,'v439');
assert.equal(next.protected_manifest.sha256,hash(base+'manifest.json'));
assert.deepEqual(Object.keys(next.files).sort(),Object.keys(prior.files).sort());
assert.deepEqual([...Object.keys(next.files),'manifest.json'].sort(),fs.readdirSync(release).sort());
for(const [name,expected] of Object.entries(prior.files)){
 assert.equal(hash(base+name),expected,'protected '+name);
 assert.equal(hash(release+name),next.files[name],'candidate '+name);
}
const changed=Object.keys(next.files).filter(name=>next.files[name]!==prior.files[name]).sort();
assert.deepEqual(changed,['app.html','lts-v412-projection-policy.js','provenance.json']);
const mobile=process.env.LTS_MOBILE_RELEASE||'v439';assert.match(mobile,/^v\d+$/);
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:mobile,entry:'../releases/'+mobile+'/app.html'});
assert(fs.readFileSync(release+'app.html','utf8').includes('V440'));
const provenance=JSON.parse(fs.readFileSync(release+'provenance.json'));
assert.equal(provenance.default_loader_promoted,false);
assert.equal(provenance.private_http_validated,false);
assert.equal(provenance.physical_mobile_validated,false);
console.log(JSON.stringify({pass:true,release:'v440',assets:Object.keys(next.files).length,changed,default_release:'v439'}));
