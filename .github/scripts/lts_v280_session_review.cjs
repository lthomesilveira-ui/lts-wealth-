'use strict';
const {environment,settle,names}=require('./lts_v280_reader_session.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),os=require('node:os');
const ROOT=path.resolve('releases/v280'),BASE=path.resolve('releases/v279');
const files=['lts-v183-v168-feedback-safe.js','lts-v183-expense-history-candidate.js'];
const results=[];async function test(name,run){try{await run();results.push({name,pass:true});console.log('PASS '+name)}catch(error){results.push({name,pass:false,error:String(error.stack||error)});console.log('FAIL '+name+' '+error.message)}}
const snapshot=e=>JSON.stringify([e.st,e.state]);
async function noRender(name,error,root=ROOT){
 const e=environment(root),old=e.begin(name),calls=[...e.calls];e.ctx.BOOT.generation++;e.ctx.D={user:'next'};
 const before=snapshot(e),renders=e.renders();e.release(calls,'old-before-render',error);await old;await settle();
 assert.equal(snapshot(e),before);assert.equal(e.renders(),renders);assert.equal(e.calls.length,calls.length);
 // Retirement also works at the next reader entry, without a preceding render.
 const fresh=e.begin(name),newCalls=e.calls.slice(calls.length);assert(newCalls.length>0);assert(e.slot(name).loading);
 e.release(newCalls,'fresh-after-reader-reset');await fresh;assert.equal(e.slot(name).loading,false);
 assert.equal((e.slot(name).data||e.slot(name).rows?.[0]).tag,'fresh-after-reader-reset');
}
(async()=>{
 for(const name of names){
  for(const error of [false,true])await test(`Generation changes before any render: ${name} old ${error?'error':'success'} is inert and reader recovers`,()=>noRender(name,error));
  await test(`Old success cannot finish a new pending read: ${name}`,async()=>{
   const e=environment(),old=e.begin(name),oldCalls=[...e.calls];e.session();const fresh=e.begin(name),newCalls=e.calls.slice(oldCalls.length),before=snapshot(e),renders=e.renders();
   e.release(oldCalls,'old-success');await old;await settle();assert.equal(snapshot(e),before);assert.equal(e.renders(),renders);assert(e.slot(name).loading);
   e.release(newCalls,'fresh');await fresh;assert.equal((e.slot(name).data||e.slot(name).rows?.[0]).tag,'fresh');
  });
 }
 await test('Session retirement preserves preferences and every slot identity, and does not change unrelated state',async()=>{
  const e=environment();e.st.wealth={data:{marker:'wealth'},loading:true};e.st.updates={data:{marker:'updates'},loading:true};e.ctx.CF={value:123.45};
  e.st.expense.key='custom';e.st.expense.customFrom='2026-08-01';e.st.expense.customTo='2026-08-31';e.st.expense.tab='cards';e.state.cards.bank='Synthetic bank';e.state.monthly.year='2025';
  const identities=names.map(n=>e.slot(n));const unrelated=JSON.stringify([e.st.wealth,e.st.updates,e.ctx.CF]);
  for(const n of names){const s=e.slot(n);s.loading=true;s.data={marker:'prior'};s.error='prior';if(n.startsWith('reader168.'))s.rows=[{marker:'prior'}]}
  e.session();names.forEach((n,i)=>assert.equal(e.slot(n),identities[i]));
  assert.equal(e.st.expense.key,'custom');assert.equal(e.st.expense.customFrom,'2026-08-01');assert.equal(e.st.expense.customTo,'2026-08-31');assert.equal(e.st.expense.tab,'cards');assert.equal(e.state.cards.bank,'Synthetic bank');assert.equal(e.state.monthly.year,'2025');assert.equal(JSON.stringify([e.st.wealth,e.st.updates,e.ctx.CF]),unrelated);
 });
 await test('Multiple generation changes cannot revive a response when the same D object is reused',async()=>{
  for(const name of names){const e=environment(),oldD=e.ctx.D,old=e.begin(name),calls=[...e.calls];e.ctx.BOOT.generation++;e.ctx.D=null;e.ctx.BOOT.generation++;e.ctx.D=oldD;const before=snapshot(e);e.release(calls,'old');await old;assert.equal(snapshot(e),before)}
 });
 await test('Original V279 is a positive counterproof for both canonical expense readers',async()=>{
  for(const name of ['reader168.expense','reader175.expense']){const e=environment(BASE),flight=e.begin(name),calls=[...e.calls];e.ctx.BOOT.generation++;e.ctx.D={user:'next'};e.release(calls,'prior-session');await flight;assert.equal(e.slot(name).data.tag,'prior-session')}
 });
 await test('Negative controls removing generation equality fail both independent before-render tests',async()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'expense-guard-negative-'));try{
   for(const f of files){let s=fs.readFileSync(path.join(ROOT,f),'utf8');s=s.replace('owner.generation===expenseDraftGeneration()&&','').replace('owner.generation===expenseReadGeneration()&&','');fs.writeFileSync(path.join(temp,f),s)}
   for(const name of ['reader168.expense','reader175.expense'])await assert.rejects(()=>noRender(name,false,temp));
  }finally{fs.rmSync(temp,{recursive:true,force:true})}
 });
 const out={scope:'Independent controlled promises on exact V168/V175 readers; no browser/network/database',hashes:Object.fromEntries(files.map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,f))).digest('hex')])),passed:results.filter(x=>x.pass).length,failed:results.filter(x=>!x.pass).length,results};fs.writeFileSync('qa/v280-session-independent-results.json',JSON.stringify(out,null,2)+'\n');console.log(`RESULT ${out.passed} PASS ${out.failed} FAIL`);if(out.failed)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
