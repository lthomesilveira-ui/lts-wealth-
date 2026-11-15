'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../releases/'+(process.env.LTS_TEST_REFRESH_RELEASE||'v447')+'/lts-v415-product-refresh.js');
const status=(state='ready',v='2')=>({state,required:state!=='ready',cached_available:true,request_version:v,completed_version:v,cached_refreshed_at:'2026-11-15T17:00:00Z'});
function harness(t,onUnavailable){let id=0;const timers=new Map(),installed=[],calls=[];let respond;const h={};
 h.c=api.create({setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:k=>timers.delete(k),rpc:name=>{calls.push(name);return respond(name)},onProduct:p=>installed.push(p),onProductUnavailable:()=>onUnavailable?.(h.c)});t.after(()=>h.c.dispose());
 h.c.acceptProduct({ok:true,mvp:{balance:123.45},refresh:status()});return Object.assign(h,{timers,installed,calls,respond:fn=>respond=fn});
}
test('same-version readiness after a cache invalidation fetches one verified complete product',async t=>{
 const h=harness(t);h.respond(()=>({data:{ok:true,refresh:status('pending')}}));await h.c.poll();assert.equal(h.c.snapshot().pending,true);
 h.respond(name=>({data:name===api.STATUS_RPC?{ok:true,refresh:status()}:{ok:true,mvp:{balance:123.45},refresh:status()}}));
 await h.c.poll();assert.equal(h.installed.length,1);assert.equal(h.c.snapshot().pending,false);assert.equal(h.c.snapshot().error,null);assert.equal(h.timers.size,0);
 await h.c.poll();assert.equal(h.calls.filter(x=>x===api.PRODUCT_RPC).length,1,'A confirmed same version is not fetched repeatedly');
});
test('coalesced recheck during a new unavailable snapshot retains the next bounded status poll',async t=>{
 const h=harness(t,c=>{c.poll()});let products=0;
 h.respond(name=>({data:name===api.STATUS_RPC?{ok:true,refresh:status('ready','3')}:{ok:true,mvp:null,refresh:status('pending','4')}}));
 await h.c.poll();assert.equal(h.c.snapshot().hasProduct,false);assert.equal(h.c.snapshot().refresh.request_version,'4');assert.equal(h.timers.size,1);assert.equal(h.c.snapshot().polling,true);
 assert.equal(h.calls.filter(x=>x===api.PRODUCT_RPC).length,1);assert(!h.calls.includes(api.REQUEST_RPC));
});
// Re-run all existing protocol, authentication, bounded recovery and admission
// contracts against this controller, keeping their opt-out explicit-stop cases.
require.cache[require.resolve('../../releases/v444/lts-v415-product-refresh.js')]={exports:api};
require('./lts_v444_refresh_test.cjs');
