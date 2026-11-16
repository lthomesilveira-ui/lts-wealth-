'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../releases/v449/lts-v415-product-refresh.js');
const turn=()=>new Promise(setImmediate);
const status=(state='ready',v='2')=>({state,required:state!=='ready',cached_available:true,request_version:v,completed_version:v,cached_refreshed_at:'2026-11-16T11:00:00Z'});
function harness(t){
 let respond,id=0;const calls=[],installed=[],timers=new Map(),auth=[];
 const controller=api.create({rpc:name=>{calls.push(name);return respond(name)},
  setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:id=>timers.delete(id),
  onProduct:value=>installed.push(value),onAuthError:error=>auth.push(error)});
 controller.acceptProduct({ok:true,mvp:{balance:123.45},refresh:status()});
 t.after(()=>controller.dispose());
 return{controller,calls,installed,timers,auth,respond:fn=>respond=fn};
}
const complete=name=>({data:name===api.STATUS_RPC?{ok:true,refresh:status()}:{ok:true,mvp:{balance:123.45},refresh:status()}});
test('a deferred failure rechecks even a nominally ready same-version snapshot',async t=>{
 const h=harness(t);h.respond(complete);
 await h.controller.recoverDeferred();
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.installed.length,1);assert.equal(h.controller.snapshot().pending,false);
 assert.equal(h.controller.snapshot().deferredRecoveries,1);
 assert.equal(h.timers.size,0);
});
test('a burst of deferred failures coalesces into one status and one complete read',async t=>{
 const h=harness(t);let answer;
 h.respond(name=>name===api.STATUS_RPC?new Promise(resolve=>answer=resolve):complete(name));
 const first=h.controller.recoverDeferred();await turn();
 const burst=Array.from({length:12},()=>h.controller.recoverDeferred());
 assert(burst.every(p=>p===first));answer(complete(api.STATUS_RPC));await Promise.all([first,...burst]);
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC]);assert.equal(h.installed.length,1);
});
test('permanent deferred failure is bounded; installing the same version does not reset its budget',async t=>{
 const h=harness(t);h.respond(complete);
 for(let i=0;i<8;i++)await h.controller.recoverDeferred();
 assert.equal(h.calls.filter(n=>n===api.STATUS_RPC).length,2);
 assert.equal(h.calls.filter(n=>n===api.PRODUCT_RPC).length,2);
 assert.equal(h.controller.snapshot().deferredRecoveries,2);
 assert(!h.calls.includes(api.REQUEST_RPC));assert.equal(h.timers.size,0);
});
test('a failure arriving during a status flight is observed after that flight',async t=>{
 const h=harness(t);let answer,count=0;
 h.respond(name=>name===api.STATUS_RPC&&++count===1?new Promise(resolve=>answer=resolve):complete(name));
 const pending=h.controller.poll();await Promise.resolve();await Promise.resolve();
 const recovery=h.controller.recoverDeferred();await Promise.resolve();
 assert.deepEqual(h.calls,[api.STATUS_RPC]);answer(complete(api.STATUS_RPC));
 await Promise.all([pending,recovery]);assert.deepEqual(h.calls,[api.STATUS_RPC,api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.controller.snapshot().pending,false);
});
test('a failure arriving during a complete-product flight is not lost or run concurrently',async t=>{
 const h=harness(t);let answer,count=0;
 h.respond(name=>name===api.PRODUCT_RPC&&++count===1?new Promise(resolve=>answer=resolve):complete(name));
 const manual=h.controller.retry();await turn();
 assert.equal(typeof answer,'function');const recovery=h.controller.recoverDeferred();await Promise.resolve();
 assert.equal(h.calls.length,2);answer(complete(api.PRODUCT_RPC));await Promise.all([manual,recovery]);
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.PRODUCT_RPC,api.STATUS_RPC,api.PRODUCT_RPC]);
 assert.equal(h.controller.snapshot().pending,false);
});
test('a new server version is followed through pending to verified full recovery',async t=>{
 const h=harness(t);let pending=true;
 h.respond(name=>({data:name===api.STATUS_RPC?{ok:true,refresh:status(pending?'pending':'ready','3')}:{ok:true,mvp:{balance:123.45},refresh:status('ready','3')}}));
 await h.controller.recoverDeferred();assert.equal(h.controller.snapshot().pending,true);
 assert.equal(h.installed.length,0);assert.equal(h.timers.size,1);
 pending=false;await h.controller.poll();assert.equal(h.installed.length,1);
 assert.equal(h.controller.snapshot().pending,false);assert(!h.calls.includes(api.REQUEST_RPC));
});
test('session stop prevents a joined recovery from reaching the next owner',async t=>{
 const h=harness(t);let answer;
 h.respond(()=>new Promise(resolve=>answer=resolve));const flight=h.controller.poll();
 await Promise.resolve();await Promise.resolve();const recovery=h.controller.recoverDeferred();
 h.controller.stop();answer(complete(api.STATUS_RPC));await Promise.all([flight,recovery]);
 assert.equal(h.calls.length,1);assert.equal(h.installed.length,0);assert.equal(h.controller.snapshot().active,false);
});
test('expired authentication does not fetch a product, request a job or retry sign-in',async t=>{
 const h=harness(t);h.respond(()=>({error:{status:401,code:'PGRST301',message:'Sessão expirada'}}));
 await h.controller.recoverDeferred();assert.deepEqual(h.calls,[api.STATUS_RPC]);
 assert.equal(h.auth.length,1);assert.equal(h.installed.length,0);assert.equal(h.timers.size,0);
});
process.env.LTS_TEST_REFRESH_RELEASE='v449';
require('./lts_v447_refresh_test.cjs');
