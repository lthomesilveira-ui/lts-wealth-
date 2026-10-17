'use strict';
// Actual immutable V283 bytes. This audit never fulfills/replaces a release asset.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fixtureRoot=path.resolve(process.env.LTS_LABEL_FIXTURE_ROOT||path.join(__dirname,'../fixtures/labels-v283'));
const baseRoot=path.resolve(process.env.LTS_LABEL_BASE_ROOT||'releases/v282');
const releaseRoot=path.resolve(process.env.LTS_LABEL_RELEASE_ROOT||'releases/v283');
const allowlist=JSON.parse(fs.readFileSync(path.join(fixtureRoot,'release-allowlist.json')));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sources=html=>[...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/g)].map(match=>match[1]);
assert.equal(allowlist.base_commit,'d1e972d69390112714a0d676bfd966f8477f14b0');assert.equal(allowlist.release,'v283');assert.equal(allowlist.assets.length,8);
for(const [root,files]of [[baseRoot,allowlist.base_files],[releaseRoot,allowlist.release_files]]){
 assert.equal(Object.keys(files).length,67);
 assert.deepEqual(fs.readdirSync(root).sort(),Object.keys(files).sort(),'Exactly 67 flat release files');
 for(const [file,hash]of Object.entries(files)){assert.equal(path.basename(file),file);assert.equal(sha(fs.readFileSync(path.join(root,file))),hash,'Immutable release byte: '+file);}
}
for(const item of allowlist.assets){assert.equal(allowlist.base_files[item.asset],item.base_sha256);assert.equal(allowlist.release_files[item.asset],item.candidate_sha256);}
const changed=Object.keys(allowlist.release_files).filter(name=>allowlist.release_files[name]!==allowlist.base_files[name]).sort();
assert.deepEqual(changed,[...allowlist.assets.map(item=>item.asset),'app.html','provenance.json','manifest.json'].sort());
assert.equal(allowlist.release_files['index.html'],allowlist.base_files['index.html']);
const expected={outer:sources(fs.readFileSync(path.join(releaseRoot,'app.html'),'utf8')),inner:sources(fs.readFileSync(path.join(releaseRoot,'index.html'),'utf8'))};
const model=fs.readFileSync(path.join(releaseRoot,'lts-dashboard-executive-v1.js'),'utf8').match(/const MODEL_SRC=['"]([^'"]+)['"]/);assert(model);
const expectedJS=[...new Set([...expected.outer,...expected.inner,model[1]].map(src=>src.split('?')[0]))].sort();
assert.equal(expected.inner[0],'lts-category-display.js','Display helper is first');
function releaseBuild(build){assert.equal(build.id,'v283');for(const [name,hash]of Object.entries(build.hashes))assert.equal(hash,allowlist.release_files[name]);assert.deepEqual(build.expected.outer,expected.outer);assert.deepEqual(build.expected.inner,expected.inner);return build;}
function audit(context,base='http://127.0.0.1:8788'){
 const origin=new URL(base);assert.equal(origin.protocol,'http:');assert(['127.0.0.1','localhost','[::1]'].includes(origin.hostname));
 const checked=new Set(),errors=[],pending=[],blocked=[];
 context.on('response',response=>{
  const url=new URL(response.url());if(url.origin!==origin.origin||!url.pathname.startsWith('/releases/v283/')||!url.pathname.endsWith('.js'))return;
  pending.push(response.body().then(bytes=>{const name=path.basename(url.pathname);assert.equal(response.status(),200);assert(allowlist.release_files[name]);assert.equal(sha(bytes),allowlist.release_files[name],'Actual served V283 hash '+name);checked.add(name);}).catch(error=>errors.push(String(error.stack||error))));
 });
 async function serve(route){const req=route.request(),url=new URL(req.url());if(url.origin!==origin.origin||!['GET','HEAD'].includes(req.method())){blocked.push({origin:url.origin,path:url.pathname,method:req.method()});return route.abort('blockedbyclient');}return route.continue();}
 async function installGuard(){await context.route('**/*',serve);}
 async function assertComplete(){await Promise.all(pending);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);assert.deepEqual([...checked].sort(),expectedJS,'All real ordered release scripts were hash-audited');return{served_from_release:'v283',route_overrides:0,base_commit:allowlist.base_commit,base_file_count:67,release_file_count:67,changed_assets:allowlist.assets.map(item=>item.asset),hashes:Object.fromEntries(allowlist.assets.map(item=>[item.asset,item.candidate_sha256])),checked_scripts:[...checked].sort(),errors,blocked};}
 return{serve,installGuard,assertComplete};
}
function summary(){return{pass:true,release:'v283',base_files:67,release_files:67,changed_product_assets:8,route_overrides:0,index_unchanged:true,expected,expected_js:expectedJS,hashes:Object.fromEntries(allowlist.assets.map(item=>[item.asset,item.candidate_sha256]))};}
module.exports={allowlist,fixtureRoot,releaseBuild,audit,summary};
if(require.main===module)console.log(JSON.stringify(summary(),null,2));
