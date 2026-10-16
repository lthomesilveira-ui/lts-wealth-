const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const before=JSON.parse(fs.readFileSync('releases/v279/manifest.json')),after=JSON.parse(fs.readFileSync('releases/v280/manifest.json'));
const changed=['app.html','provenance.json','lts-v183-v168-feedback-safe.js','lts-v183-expense-history-candidate.js'];
assert.deepEqual(Object.keys(before.files).sort(),Object.keys(after.files).sort());
for(const[n,h]of Object.entries(before.files))if(!changed.includes(n))assert.equal(after.files[n],h,n);
const expected={'lts-v183-v168-feedback-safe.js':'296cf234f1c5d306879a8fe88b8277ffb49fa59503e5683fac3901609c20f932','lts-v183-expense-history-candidate.js':'ff0b6997cf319cb3a7069292c847caf539155c8e279e865e2348d32742f30e32'};
for(const[n,h]of Object.entries(expected))assert.equal(crypto.createHash('sha256').update(fs.readFileSync('releases/v280/'+n)).digest('hex'),h,n);
assert(fs.readFileSync('releases/v279/index.html').equals(fs.readFileSync('releases/v280/index.html')));console.log('Two reviewed expense editor assets; all other assets protected');
