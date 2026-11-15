'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../releases/v444/lts-v415-product-refresh.js');
const flush=async()=>{for(let i=0;i<50;i++)await Promise.resolve()};
const status=(state='pending')=>({state,required:state!=='ready',cached_available:true,request_version:'2',completed_version:state==='ready'?'2':'1'});
function harness(t){
 let id=0;const timers=new Map(),calls=[],installed=[],auth=[];let response;
 const c=api.create({setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:k=>timers.delete(k),
 rpc:(name,args,signal)=>{calls.push(name);return response(name,signal)},onProduct:p=>installed.push(p),onAuthError:e=>auth.push(e)});
 c.acceptProduct({ok:true,mvp:{balance:123.45},refresh:status()});t.after(()=>c.dispose());
 return{c,timers,calls,installed,auth,respond:fn=>response=fn,async tick(){assert.equal(timers.size,1);const [k,v]=[...timers][0];timers.delete(k);v.fn();await flush();return v.ms}};
}
test('a transient status error recovers automatically through status and one complete product',async t=>{
 const h=harness(t);h.respond(()=>({error:{status:503}}));await h.tick();assert.equal(h.c.snapshot().error,'status');
 h.respond(name=>({data:name===api.STATUS_RPC?{ok:true,refresh:status('ready')}:{ok:true,mvp:{balance:123.45},refresh:status('ready')}}));
 assert.equal(await h.tick(),10000);assert.equal(h.installed.length,1);assert.equal(h.c.snapshot().pending,false);assert.equal(h.timers.size,0);
 assert.deepEqual(h.calls,[api.STATUS_RPC,api.STATUS_RPC,api.PRODUCT_RPC]);
});
test('a failed product retries only after status verification and never requests a new server job',async t=>{
 const h=harness(t);let products=0;
 h.respond(name=>name===api.STATUS_RPC?{data:{ok:true,refresh:status('ready')}}:++products===1?{error:{message:'Failed to fetch'}}:{data:{ok:true,mvp:{balance:123.45},refresh:status('ready')}});
 await h.tick();assert.equal(h.c.snapshot().error,'product');assert.equal(h.installed.length,0);await h.tick();
 assert.equal(h.installed.length,1);assert.equal(products,2);assert(!h.calls.includes(api.REQUEST_RPC));assert.equal(h.timers.size,0);
});
test('transient recovery has two attempts, preserves the original 10s deadline and then remains actionable',async t=>{
 const h=harness(t);let signals=[];h.respond((name,signal)=>{signals.push(signal);return new Promise(()=>{})});
 const poll=h.c.poll();await flush();assert.equal(await h.tick(),10000);await poll;
 assert(signals[0].aborted);assert.equal(await h.tick(),10000);assert.equal(await h.tick(),10000);
 assert.equal(await h.tick(),20000);assert.equal(await h.tick(),10000);
 assert.equal(h.calls.length,3);assert.equal(h.c.snapshot().error,'status');assert.equal(h.timers.size,0);assert(signals.every(x=>x.aborted));
});
test('authentication, protocol contradiction and backend job failure never auto retry',async t=>{
 for(const error of[{status:401},{code:'PGRST301'},{message:'Sessão expirada'},{status:403},{code:'23514'}]){
  const h=harness(t);h.respond(()=>({error}));await h.tick();assert.equal(h.timers.size,0);assert.equal(h.calls.length,1);
  assert.equal(h.auth.length,error.status===401||error.code==='PGRST301'||error.message==='Sessão expirada'?1:0);
 }
 const h=harness(t);h.respond(()=>({data:{ok:true,refresh:{...status(),request_version:'invalid'}}}));await h.tick();assert.equal(h.timers.size,0);
 const failed=harness(t);failed.respond(()=>({data:{ok:true,refresh:status('failed')}}));await failed.tick();assert.equal(failed.timers.size,0);assert.equal(failed.installed.length,0);
});
test('pause and logout cancel scheduled recovery without an extra read or late financial installation',async t=>{
 for(const stop of['pause','stop','dispose']){const h=harness(t);h.respond(()=>({error:{status:503}}));await h.tick();assert.equal(h.timers.size,1);h.c[stop]();assert.equal(h.timers.size,0);assert.equal(h.calls.length,1);assert.equal(h.installed.length,0)}
});
// Run the previous protocol/deadline contracts with automatic recovery disabled
// to retain their explicit-stop assertions, then test the new default above.
const compatibility={...api,create:options=>api.create({...options,maxTransientRetries:0})};
require.cache[require.resolve('../../lts-v415-product-refresh.js')]={exports:compatibility};
require('./lts_v415_refresh_test.cjs');

require.cache[require.resolve('../../releases/v441/lts-v415-product-refresh.js')]={exports:compatibility};
require('./lts_v441_refresh_test.cjs');
