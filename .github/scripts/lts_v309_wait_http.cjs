'use strict';
// Readiness is required before browser assertions; connection failures remain fatal.
const release=process.env.LTS_RELEASE||'v309';
if(!/^v[0-9]+(?:-[0-9]+)?$/.test(release))throw Error('Invalid local test release');
const url='http://127.0.0.1:8788/releases/'+release+'/app.html';
(async()=>{
 const deadline=Date.now()+15000;let last='No response';
 while(Date.now()<deadline){
  try{
   const response=await fetch(url,{signal:AbortSignal.timeout(Math.min(1000,Math.max(1,deadline-Date.now())))});
   if(response.ok){await response.body?.cancel();console.log('Local application ready: '+release);return;}
   last='HTTP '+response.status;await response.body?.cancel();
  }catch(error){last=error.message;}
  await new Promise(resolve=>setTimeout(resolve,100));
 }
 throw Error('Local application did not become ready: '+release+' ('+last+')');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
