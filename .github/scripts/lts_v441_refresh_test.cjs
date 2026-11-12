'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../releases/v441/lts-v415-product-refresh.js');
// Reuse every prior protocol test against the actual new controller.
require.cache[require.resolve('../../lts-v415-product-refresh.js')]={exports:api};
require('./lts_v415_refresh_test.cjs');
const status=state=>({state,required:state!=='ready',cached_available:true,request_version:'2',completed_version:state==='ready'?'2':'1'});
const flush=async()=>{for(let i=0;i<40;i++)await Promise.resolve();};
function harness(t){let id=0,start,resolve,signal;const timers=new Map(),installed=[];
 const c=api.create({deferProductDeadline:true,setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id;},clearTimeout:k=>timers.delete(k),
 rpc:(name,args,s,onStart)=>{if(name===api.STATUS_RPC)return {data:{ok:true,refresh:status('ready')}};signal=s;start=onStart;return new Promise(r=>resolve=r);},onProduct:p=>installed.push(p)});
 t.after(()=>c.dispose());c.acceptProduct({ok:true,mvp:{balance:7},refresh:status('pending')});
 return{c,timers,installed,get signal(){return signal;},admit(){start();},complete(){resolve({data:{ok:true,mvp:{balance:7},refresh:status('ready')}});},async expire(ms){const e=[...timers].find(([,v])=>v.ms===ms);assert(e,`timer ${ms}`);timers.delete(e[0]);e[1].fn();await flush();}};
}
test('a queued product has only the existing 60s admission bound; query gets 25s after admission',async t=>{const h=harness(t),p=h.c.poll();await flush();assert([...h.timers.values()].some(x=>x.ms===60000));assert(![...h.timers.values()].some(x=>x.ms===25000));assert(!h.signal.aborted);h.admit();assert(![...h.timers.values()].some(x=>x.ms===60000));assert([...h.timers.values()].some(x=>x.ms===25000));h.complete();await p;assert.equal(h.installed.length,1);assert.equal(h.timers.size,0);});
test('an admitted query still aborts after the original 25s',async t=>{const h=harness(t),p=h.c.poll();await flush();h.admit();await h.expire(25000);await p;assert(h.signal.aborted);assert.equal(h.installed.length,0);assert.equal(h.c.snapshot().error,'product');});
test('missing admission cannot leave an unbounded product request',async t=>{const h=harness(t),p=h.c.poll();await flush();await h.expire(60000);await p;assert(h.signal.aborted);h.admit();h.complete();await flush();assert.equal(h.installed.length,0);assert.equal(h.timers.size,0);});
