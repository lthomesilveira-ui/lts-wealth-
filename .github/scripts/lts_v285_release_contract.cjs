'use strict';
// Complete immutable release contract, with exact reconstruction of its sole product change.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const allowPath=path.join(__dirname,'../fixtures/context-v285/release-allowlist.json');
assert.equal(sha(fs.readFileSync(allowPath)),'ed90d9fab34efe8d9bf7b503846b46a60a6854fcea21877a3e2eff6da344e4cb','Reviewed complete release inventory');
const allow=JSON.parse(fs.readFileSync(allowPath));
assert.equal(allow.base_commit,'99f06d0e54011e4613ededb13f754657511aa5a8');
assert.equal(allow.base_release,'v284');assert.equal(allow.release,'v285');
for(const [release,files]of [['v284',allow.base_files],['v285',allow.release_files]]){
 const root=path.join('releases',release);assert.equal(Object.keys(files).length,67);
 assert.deepEqual(fs.readdirSync(root).sort(),Object.keys(files).sort());
 for(const [file,expected]of Object.entries(files)){
  assert.equal(path.basename(file),file);assert.equal(sha(fs.readFileSync(path.join(root,file))),expected,release+'/'+file);
 }
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
 assert.equal(manifest.release,release);assert.equal(manifest.version,release);assert.equal(Object.keys(manifest.files).length,66);
 for(const [file,expected]of Object.entries(manifest.files))assert.equal(files[file],expected);
 for(const [file,expected]of Object.entries(manifest.protected))assert.equal(sha(fs.readFileSync(file)),expected,'Protected history: '+file);
}
const changed=Object.keys(allow.release_files).filter(file=>allow.release_files[file]!==allow.base_files[file]).sort();
assert.deepEqual(changed,['app.html','lts-v181-regression-closure.js','manifest.json','provenance.json'].sort());
const edits=JSON.parse(fs.readFileSync('.github/fixtures/person-context-copy/overlay/edits.json'));
let candidate=fs.readFileSync(path.join('releases/v284',edits.asset),'utf8');
assert.equal(sha(candidate),'8a7247e7d5b41d4fe511d27edb95037924b97d4b7368d7a67ff4c36e5e833023');
assert.equal(edits.operations.length,4);
for(const op of edits.operations){assert.equal(candidate.split(op.from).length-1,1);candidate=candidate.replace(op.from,op.to);}
assert.equal(sha(candidate),'75942324eae28e090e05617c2c1efbfc85950272d082705f7754278f9a02faa5');
assert.equal(candidate,fs.readFileSync(path.join('releases/v285',edits.asset),'utf8'));
const app=fs.readFileSync('releases/v284/app.html','utf8').replaceAll('V284','V285').replace('v284-projection-coverage-20261017','v285-person-context-20261017');
assert.equal(app,fs.readFileSync('releases/v285/app.html','utf8'));
assert(!candidate.includes('Categorias sem nome de pessoa são suas'));
assert(candidate.includes("label==='Minhas despesas (sem prefixo)'?'Demais grupos':label"));
assert.equal(allow.release_files['lts-v179-cash-recovery.js'],allow.base_files['lts-v179-cash-recovery.js']);
assert.equal(allow.release_files['index.html'],allow.base_files['index.html']);
assert.equal(sha(fs.readFileSync('index.html')),'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
console.log(JSON.stringify({pass:true,release:'v285',base:'v284',files:67,product_assets_changed:1,exact_copy_edits:4,financial_code_unchanged:true,coverage_guards_preserved:true}));
