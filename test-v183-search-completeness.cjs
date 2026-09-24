'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-search-completeness.js','utf8');
const args={p_from:'2013-10-10',p_to:null,p_query:'fixture',p_direction:null,p_account:null,p_limit:200,p_offset:0};
function harness(rpc){const search={seq:1,query:'fixture'},context={window:{__LTS_V168_STATE:{search}},S:{rpc}};vm.runInNewContext('('+source.slice(source.indexOf('function runtime(){'),source.indexOf('\n const shell='))+')()',context);return {search,call:(a=args)=>context.S.rpc('lts_browser_transactions_v2',a)}}
const page=(offset,total)=>({data:{total,offset,rows:Array.from({length:Math.min(200,total-offset)},(_,i)=>({source:'fixture',source_ref:String(offset+i),date:'2026-01-01',amount:1}))}});
test('complete search retrieves rows beyond the old 200 ceiling',async()=>{
 const calls=[],h=harness(async(n,a)=>{calls.push(a.p_offset);return page(a.p_offset,239)}),r=await h.call();
 assert.deepEqual(calls,[0,200]);assert.equal(r.data.rows.length,239);assert.equal(r.data.complete,true);assert.equal(r.data.rows[238].source_ref,'238');
});
test('empty search result is complete without extra pages',async()=>{let calls=0;const r=await harness(async()=>{calls++;return page(0,0)}).call();assert.equal(calls,1);assert.equal(r.data.rows.length,0)});
test('other transaction uses pass through without pagination',async()=>{const original={data:{rows:[]}},h=harness(async()=>original);assert.equal(await h.call({...args,p_direction:'expense'}),original)});
test('missing page, changed count or duplicate rows fail closed',async()=>{
 for(const bad of [{data:{total:239,rows:[]}},{data:{total:240,rows:page(200,240).data.rows}},{data:{total:239,rows:page(0,39).data.rows}},{error:{message:'offline'}}]){
  const h=harness(async(n,a)=>a.p_offset?bad:page(0,239)),r=await h.call();assert.equal(r.data,null);assert.ok(r.error);
 }
});
test('new query cancels remaining pages without touching its state',async()=>{
 let resolve,calls=0;const h=harness(()=>{calls++;return new Promise(r=>resolve=r)}),job=h.call();h.search.seq++;h.search.query='new';resolve(page(0,239));const result=await job;assert.equal(calls,1);assert.equal(result.data,null);assert.equal(h.search.query,'new');
});
test('unbounded result is explicit, never silently capped',async()=>{const h=harness(async()=>page(0,10001)),r=await h.call();assert.equal(r.data,null);assert.match(r.error.message,/10.000/)});
test('candidate only and no financial writes',()=>{assert.doesNotThrow(()=>new Function(source));assert.doesNotMatch(source,/\.insert\(|\.update\(|\.delete\(/);assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-search-completeness/)});
