'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const origin='https://lthomesilveira-ui.github.io/lts-wealth-/';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function verify(path,expected){
 let failure;
 for(let attempt=0;attempt<4;attempt++){
  try{
   const response=await fetch(origin+path+'?verify='+process.env.GITHUB_SHA,{cache:'no-store',signal:AbortSignal.timeout(15000)});
   assert(response.ok,path+' HTTP '+response.status);const bytes=Buffer.from(await response.arrayBuffer());
   assert.equal(sha(bytes),expected,path+' served bytes');return {path,sha256:expected,bytes:bytes.length,pass:true};
  }catch(error){failure=error;if(attempt<3)await new Promise(resolve=>setTimeout(resolve,5000));}
 }
 throw failure;
}
(async()=>{
 const entries=[];
 for(const release of ['v386','v385','v384','v383','v382','v379']){
  const root='releases/'+release+'/',raw=fs.readFileSync(root+'manifest.json'),manifest=JSON.parse(raw);
  const files={...manifest.files,'manifest.json':sha(raw)};
  assert.deepEqual(Object.keys(files).sort(),fs.readdirSync(root).sort(),'every release asset is covered');
  for(const[name,expected]of Object.entries(files))entries.push([root+name,expected]);
 }
 const current=JSON.parse(fs.readFileSync('mobile/current.json'));
 assert.deepEqual(current,{release:'v386',entry:'../releases/v386/app.html'});
 for(const path of ['mobile/current.json','mobile/index.html','mobile/launcher.js','mobile/manifest.webmanifest','mobile/icon.svg','mobile/apple-touch-icon.png'])entries.push([path,sha(fs.readFileSync(path))]);
 const assets=[];for(let offset=0;offset<entries.length;offset+=6)assets.push(...await Promise.all(entries.slice(offset,offset+6).map(([path,expected])=>verify(path,expected))));
 assert.equal(assets.length,entries.length);assert.equal(new Set(assets.map(x=>x.path)).size,entries.length);
 fs.writeFileSync('v386-published-verification.json',JSON.stringify({pass:true,head:process.env.GITHUB_SHA,ui:'v386',url:origin+'mobile/',assets,private_session:false,physical_iphone:false},null,2));
 console.log(JSON.stringify({pass:true,ui:'v386',served_assets:assets.length,previous_ui:['v385','v384','v383','v382','v379'],stable_mobile_entry:true}));
})().catch(error=>{console.error(error);process.exitCode=1});
