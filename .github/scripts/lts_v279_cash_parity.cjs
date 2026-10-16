const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const before=JSON.parse(fs.readFileSync('releases/v278/manifest.json')),after=JSON.parse(fs.readFileSync('releases/v279/manifest.json'));
const changed=['app.html','provenance.json','lts-v179-cash-recovery.js','lts-v225-open-finance.js','lts-v228-bank-flow.js'];
assert.deepEqual(Object.keys(before.files).sort(),Object.keys(after.files).sort());
for(const [n,h]of Object.entries(before.files))if(!changed.includes(n))assert.equal(after.files[n],h,n);
const expected={'lts-v179-cash-recovery.js':'b9aff5f4ce2316b9af842d81c5a6aedad643b1abf7b7130eaba249594d16a2d6','lts-v225-open-finance.js':'9a21e6c8e8f2b49185e9881804561f347258cdbfccdd48315ed09a8dd766146c','lts-v228-bank-flow.js':'d89a791e19111908c06875a769d331cdbe512a44ef0425be636c8ba6b99f03bf'};
for(const[n,h]of Object.entries(expected))assert.equal(crypto.createHash('sha256').update(fs.readFileSync('releases/v279/'+n)).digest('hex'),h,n);
assert(fs.readFileSync('releases/v278/index.html').equals(fs.readFileSync('releases/v279/index.html')));console.log('Three reviewed assets only; index and financial assets protected');
