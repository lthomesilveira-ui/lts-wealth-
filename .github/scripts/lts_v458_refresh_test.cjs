'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../releases/v458/lts-v415-product-refresh.js');
const turn=()=>new Promise(setImmediate);
const state=(phase='ready',v='2')=>({state:phase,required:phase!=='ready',cached_available:true,request_version:v,completed_version:phase==='ready'?v:'1',cached_refreshed_at:'2026-11-17T11:00:00Z'});
function harness(t,phase='ready'){
 let respond,id=0;const calls=[],installed=[],timers=new Map(),auth=[];
 const controller=api.create({rpc:name=>{calls.push(name);return respond(name)},
  setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:id=>timers.delete(id),
  onProduct:value=>installed.push(value),onAuthError:e=>auth.push(e)});
 controller.acceptProduct({ok:true,mvp:{balance:123.45},refresh:state(phase)});
 t.after(()=>controller.dispose());
 return{controller,calls,installed,timers,auth,respond:fn=>respond=fn};
}
const complete=(name,v='2')=>({data:name===api.STATUS_RPC?{ok:true,refresh:state('ready',v)}:{ok:true,mvp:{balance:123.45},refresh:state('ready',v)}});
for(const phase of ['pending','running'])test(phase+' reader bursts preserve the existing poll and full-product recovery budget',async t=>{
 const h=harness(t,phase),original=[...h.timers];h.respond(name=>complete(name));
 for(let i=0;i<30;i++)await h.controller.recoverDeferred();
 assert.deepEqual([...h.timers],original,'No timer replacement or delay reset');
 assert.equal(h.controller.snapshot().deferredRecoveries,0);assert.deepEqual(h.calls,[]);
 await h.controller.poll();assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.installed.length,1);assert.equal(h.controller.snapshot().pending,false);
 assert.equal(h.timers.size,0);assert(!h.calls.includes(api.REQUEST_RPC));
});
test('known running readers join a status flight without another read or budget use',async t=>{
 const h=harness(t,'running');let answer;
 h.respond(name=>name===api.STATUS_RPC?new Promise(resolve=>answer=resolve):complete(name));
 const first=h.controller.poll();await turn();
 const burst=Array.from({length:12},()=>h.controller.recoverDeferred());
 assert(burst.every(p=>p===first));answer(complete(api.STATUS_RPC));await Promise.all(burst);
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.controller.snapshot().deferredRecoveries,0);
});
test('ready same-version failures still have exactly two full-product retries',async t=>{
 const h=harness(t);h.respond(complete);
 for(let i=0;i<20;i++)await h.controller.recoverDeferred();
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC,api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.controller.snapshot().deferredRecoveries,2);assert.equal(h.timers.size,0);
});
test('observing a new bank job resets recovery for that version only',async t=>{
 const h=harness(t);h.respond(complete);
 await h.controller.recoverDeferred();await h.controller.recoverDeferred();
 await h.controller.observeRefresh(state('running','3'));
 for(let i=0;i<20;i++)await h.controller.recoverDeferred();
 assert.equal(h.controller.snapshot().deferredRecoveries,0);assert.equal(h.calls.length,4);
 h.respond(name=>complete(name,'3'));await h.controller.poll();
 assert.equal(h.installed.length,3);assert.equal(h.controller.snapshot().refresh.request_version,'3');
});
test('status polling remains bounded even with repeated deferred readers',async t=>{
 const h=harness(t,'running');h.respond(()=>({data:{ok:true,refresh:state('running')}}));
 for(let i=0;i<30;i++){await h.controller.recoverDeferred();await h.controller.poll()}
 assert.equal(h.calls.length,api.MAX_STATUS_POLLS);assert.equal(h.controller.snapshot().error,'waiting');
 assert.equal(h.controller.snapshot().deferredRecoveries,2,'Existing error recovery is bounded too');
 assert.equal(h.timers.size,0);assert.equal(h.installed.length,0);
});
test('late joined status cannot install a product after the owner session stops',async t=>{
 const h=harness(t,'running');let answer;h.respond(()=>new Promise(resolve=>answer=resolve));
 const first=h.controller.poll();await turn();const joined=h.controller.recoverDeferred();
 h.controller.stop();answer(complete(api.STATUS_RPC));await Promise.all([first,joined]);
 assert.equal(h.calls.length,1);assert.equal(h.installed.length,0);assert.equal(h.controller.snapshot().active,false);
});
test('authentication errors and failed jobs retain their existing explicit actions',async t=>{
 const h=harness(t,'running');h.respond(()=>({error:{status:401,code:'PGRST301',message:'Sessão expirada'}}));
 await h.controller.poll();assert.equal(h.auth.length,1);assert.equal(h.timers.size,0);assert.equal(h.installed.length,0);
 const failed=harness(t,'failed');failed.respond(()=>{throw Error('No automatic request expected')});
 assert.equal(failed.timers.size,0);assert.deepEqual(failed.calls,[]);
});
// Existing interrupted-read, failed-envelope, auth and deadline scenarios.
process.env.LTS_TEST_REFRESH_RELEASE='v458';
require('./lts_v447_refresh_test.cjs');
