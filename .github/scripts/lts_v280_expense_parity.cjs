const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const before=JSON.parse(fs.readFileSync('releases/v279/manifest.json')),after=JSON.parse(fs.readFileSync('releases/v280/manifest.json'));
const changed=['app.html','provenance.json','lts-v183-v168-feedback-safe.js','lts-v183-expense-history-candidate.js'];
assert.deepEqual(Object.keys(before.files).sort(),Object.keys(after.files).sort());
for(const[n,h]of Object.entries(before.files))if(!changed.includes(n))assert.equal(after.files[n],h,n);
const expected={'lts-v183-v168-feedback-safe.js':'2be21d59c6a651e5673d3f6d7a7099f22e1d276feb6bf68e11be11f50a23c80c','lts-v183-expense-history-candidate.js':'0d10c24c5142aa77d098551838300e9aab12d70b8d7a328315525c9d5581438d'};
for(const[n,h]of Object.entries(expected))assert.equal(crypto.createHash('sha256').update(fs.readFileSync('releases/v280/'+n)).digest('hex'),h,n);
assert(fs.readFileSync('releases/v279/index.html').equals(fs.readFileSync('releases/v280/index.html')));console.log('Two reviewed expense editor assets; all other assets protected');
