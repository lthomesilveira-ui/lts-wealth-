const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const before=JSON.parse(fs.readFileSync('releases/v277/manifest.json')),after=JSON.parse(fs.readFileSync('releases/v278/manifest.json'));
const changed=['app.html','provenance.json','lts-v183-v168-feedback-safe.js','lts-v170-v169-review.js'];
assert.deepEqual(Object.keys(before.files).sort(),Object.keys(after.files).sort());
for(const [name,hash] of Object.entries(before.files))if(!changed.includes(name))assert.equal(after.files[name],hash,'Protected unchanged asset '+name);
const expected={'lts-v183-v168-feedback-safe.js':'0bc5937305a25eccb46ead7b6e0031c375d00b020782342b76d28a4ab6faa7d5','lts-v170-v169-review.js':'af4f9cf137b1f0a0d8e8636c35371c8a136313adc39b9e9141a2d3cf3b2f8455'};
for(const [name,hash]of Object.entries(expected))assert.equal(crypto.createHash('sha256').update(fs.readFileSync('releases/v278/'+name)).digest('hex'),hash,'Exact independently reviewed observer patch');
const index=fs.readFileSync('releases/v277/index.html');assert(index.equals(fs.readFileSync('releases/v278/index.html')));
console.log('Only the two reviewed observer assets and release metadata changed; financial index and all other assets byte-identical.');
