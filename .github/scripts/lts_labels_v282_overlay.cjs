'use strict';
// Public, synthetic-only overlay. Reads local reviewed bytes; never modifies a release.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fixtureRoot=path.resolve(process.env.LTS_LABEL_FIXTURE_ROOT||path.join(__dirname,'../fixtures/labels-v282'));
const baseRoot=path.resolve(process.env.LTS_LABEL_BASE_ROOT||'releases/v282');
const allowlist=JSON.parse(fs.readFileSync(path.join(fixtureRoot,'public-allowlist.json')));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sources=html=>[...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/g)].map(match=>match[1]);
const names=['lts-category-display.js','lts-v178-review-actions.js','lts-v179-cash-recovery.js','lts-v181-regression-closure.js','lts-v183-expense-history-candidate.js','lts-v183-v168-feedback-safe.js','lts-v183-v173-feedback-safe.js','lts-v183-v182-feedback-safe.js'];
assert.equal(allowlist.base_commit,'d1e972d69390112714a0d676bfd966f8477f14b0');
assert.equal(Object.keys(allowlist.base_files).length,67,'Full published V282 receipt');
assert.deepEqual(allowlist.assets.map(item=>item.asset).sort(),names.slice().sort(),'Only the reviewed eight assets');
const candidateBytes=new Map(),hashes={...allowlist.base_files};
for(const [file,hash]of Object.entries(allowlist.base_files)){
 assert.equal(path.basename(file),file,'Flat immutable release file');
 assert.equal(sha(fs.readFileSync(path.join(baseRoot,file))),hash,'Published base byte: '+file);
}
for(const item of allowlist.assets){
 assert.equal(allowlist.base_files[item.asset],item.base_sha256,'Overlay before hash');
 const bytes=fs.readFileSync(path.join(fixtureRoot,'candidate',item.asset));
 assert.equal(sha(bytes),item.candidate_sha256,'Overlay after hash: '+item.asset);
 candidateBytes.set(item.asset,bytes);hashes[item.asset]=item.candidate_sha256;
}
const expected={outer:sources(fs.readFileSync(path.join(baseRoot,'app.html'),'utf8')),inner:sources(fs.readFileSync(path.join(baseRoot,'index.html'),'utf8'))};
assert.equal(expected.inner[0],'lts-category-display.js','Display helper loads first in the iframe');
function overlayBuild(build){
 assert.equal(build.id,'v282');
 for(const [name,hash]of Object.entries(build.hashes))assert.equal(hash,allowlist.base_files[name]);
 assert.deepEqual(build.expected.outer,expected.outer);assert.deepEqual(build.expected.inner,expected.inner);
 return {...build,hashes:{...build.hashes,...Object.fromEntries(allowlist.assets.map(item=>[item.asset,item.candidate_sha256]))},labelOverlay:true};
}
function audit(context,base='http://127.0.0.1:8788'){
 const origin=new URL(base);assert.equal(origin.protocol,'http:');assert(['127.0.0.1','localhost','[::1]'].includes(origin.hostname));
 const served=new Set(),checked=new Set(),errors=[],pending=[],blocked=[];
 context.on('response',response=>{
  const url=new URL(response.url());if(url.origin!==origin.origin||!url.pathname.startsWith('/releases/v282/')||!url.pathname.endsWith('.js'))return;
  pending.push(response.body().then(bytes=>{const name=path.basename(url.pathname);assert.equal(response.status(),200);assert(hashes[name],'Unexpected release script '+name);assert.equal(sha(bytes),hashes[name],'Actual served script hash '+name);checked.add(name);}).catch(error=>errors.push(String(error.stack||error))));
 });
 async function serve(route){
  const req=route.request(),url=new URL(req.url());
  if(url.origin!==origin.origin||!['GET','HEAD'].includes(req.method())){blocked.push({origin:url.origin,path:url.pathname,method:req.method()});return route.abort('blockedbyclient');}
  const name=path.basename(url.pathname);
  if(url.pathname==='/releases/v282/'+name&&candidateBytes.has(name)){
   const body=candidateBytes.get(name);assert.equal(sha(body),hashes[name]);served.add(name);
   return route.fulfill({status:200,contentType:'application/javascript',headers:{'Cache-Control':'no-store'},body:req.method()==='HEAD'?'':body});
  }
  return route.continue();
 }
 async function installGuard(){await context.route('**/*',serve);}
 async function assertComplete(){
  await Promise.all(pending);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  assert.deepEqual([...served].sort(),names.slice().sort(),'All eight candidate assets actually served');
  for(const name of names)assert(checked.has(name),'All eight actual response bodies audited');
  return {base_commit:allowlist.base_commit,base_file_count:67,overlay_assets:[...served].sort(),hashes:Object.fromEntries(allowlist.assets.map(item=>[item.asset,item.candidate_sha256])),errors,blocked};
 }
 return {serve,installGuard,assertComplete};
}
function summary(){return {pass:true,base_commit:allowlist.base_commit,base_files:67,overlay_assets:8,expected,hashes:Object.fromEntries(allowlist.assets.map(item=>[item.asset,item.candidate_sha256]))};}
module.exports={allowlist,fixtureRoot,overlayBuild,audit,summary};
if(require.main===module)console.log(JSON.stringify(summary(),null,2));
