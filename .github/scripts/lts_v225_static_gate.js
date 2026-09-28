'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root='releases/v225',digest=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const manifest=JSON.parse(fs.readFileSync(root+'/manifest.json'));
for(const [name,hash] of Object.entries(manifest.files)) {
  const file=path.join(root,name);assert.equal(digest(file),hash,'immutable asset '+name);
  if(name.endsWith('.js'))new Function(fs.readFileSync(file,'utf8'));
  const text=fs.readFileSync(file,'utf8');
  for(const match of text.matchAll(/['"]([a-zA-Z][a-zA-Z0-9_.-]+\.(?:js|css))(?:\?[^'"]*)?['"]/g)) {
    assert(fs.existsSync(path.join(root,match[1])),name+' has missing local dependency '+match[1]);
  }
}
for(const [file,hash] of Object.entries(manifest.protected))assert.equal(digest(file),hash,'historical evidence '+file);
assert.equal(digest('index.html'),'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
assert.match(fs.readFileSync(root+'/lts-v179-cash-recovery.js','utf8'),/dashboard=dashboard178/);
assert.match(fs.readFileSync(root+'/lts-v183-v168-feedback-safe.js','utf8'),/!window.__LTS_V166_FEEDBACK\?\.installed/);
console.log(JSON.stringify({pass:true,assets:Object.keys(manifest.files).length,protected:Object.keys(manifest.protected).length}));
