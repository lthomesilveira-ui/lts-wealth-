'use strict';
// Preserve the entire reviewed refresh regression. Its initializing scenario
// contains one historical iframe path; target the explicitly selected mobile
// entry without changing assertions, scenarios, fixtures or production assets.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const filename=path.join(__dirname,'lts_v415_refresh_browser.cjs');
let source=fs.readFileSync(filename,'utf8');
const bytes=Buffer.from(source),sha=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+bytes.length+'\0'),bytes])).digest('hex');
assert.equal(sha,'4682bdde860386f8d6453e6ad082e5bf08aa2509','review the adapter when the original suite changes');
const release=process.env.LTS_MOBILE_RELEASE||'v415';assert.match(release,/^v[0-9]+$/);
const pointer=JSON.parse(fs.readFileSync(path.join(__dirname,'../../mobile/current.json'),'utf8'));
assert.deepEqual(pointer,{release,entry:'../releases/'+release+'/app.html'});
const previous='/releases/v415/index.html';assert.equal(source.split(previous).length,2,'exactly one initializing-frame target');
source=source.replace(previous,'/releases/'+release+'/index.html');
console.log(JSON.stringify({suite:'v415-durable-refresh',mobile_release:release,assertions_preserved:true,production_files_modified:false}));
module._compile(source,filename);
