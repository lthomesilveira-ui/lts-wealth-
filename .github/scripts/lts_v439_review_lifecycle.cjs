'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const results=[],flush=()=>new Promise(resolve=>setImmediate(resolve));
function harness(release){
 const source=fs.readFileSync('releases/'+release+'/lts-v181-regression-closure.js','utf8');
 const rpc=source.slice(source.indexOf('  async function rpc('),source.indexOf('  function optionRows('));
 const start=source.indexOf('  const reviewGeneration=');
 const load=source.slice(start,source.indexOf('  async function ensureReconciliation(',start));
 const requests=[],listeners=new Map(),timers=new Map();let timer=0;
 const context={state:{review:{status:'idle',data:null,key:'',offset:0,query:'',drafts:new Map()}},BOOT:{generation:'owner-a'},D:{},
  window:{__LTS_V227_TRANSPORT:{installed:true},addEventListener:(name,fn)=>listeners.set(name,fn)},
  today:()=> '2026-11-08',render:()=>{},setTimeout:(fn,ms)=>{timers.set(++timer,{fn,ms});return timer;},clearTimeout:id=>timers.delete(id),
  S:{rpc:(name,args)=>{let resolve;const promise=new Promise(r=>resolve=r);requests.push({name,args,resolve});return promise;}}};
 vm.createContext(context);vm.runInContext(rpc+'\n'+load,context);
 return{context,requests,load:force=>vm.runInContext('ensureReview('+!!force+')',context),sync:()=>vm.runInContext('syncReviewSession()',context),event:()=>listeners.get('lts:card-classified')?.()};
}
function packet(request,count=0){return{from:request.args.p_from,to:request.args.p_to,offset:request.args.p_offset,row_count:count,matched_count:count,rows:count?[{key:'sample-review',description:'Sample expense',source_ref:'synthetic-only'}]:[],next_offset:null};}
async function finish(h,index,count=0,error=false){h.requests[index].resolve(error?{error:{message:'Synthetic failure'}}:{data:packet(h.requests[index],count)});await flush();}
(async()=>{
 for(const release of ['v436','v439']){
  const h=harness(release),first=h.load();await finish(h,0,1);await first;h.event();
  assert.equal(h.requests.length,release==='v436'?1:2);
  if(release==='v439'){assert.equal(h.context.state.review.status,'loading');assert.equal(h.context.state.review.data.row_count,1);await finish(h,1);assert.equal(h.context.state.review.data.row_count,0);}
  else assert.equal(h.context.state.review.data.row_count,1);
  results.push({case:'saved-card-invalidates-ready-list',release,pass:true});
 }
 {
  const h=harness('v439'),old=h.load();h.event();assert.equal(h.requests.length,2);
  await finish(h,0,1);await old;assert.equal(h.context.state.review.status,'loading');assert.equal(h.context.state.review.data,null);
  await finish(h,1);assert.equal(h.context.state.review.status,'ready');assert.equal(h.context.state.review.data.row_count,0);
  results.push({case:'pre-decision-response-cannot-reopen-row',pass:true});
 }
 {
  const h=harness('v439'),first=h.load();await finish(h,0,1);await first;
  h.context.state.review.drafts.set('another-row',{category:'Sample category'});h.context.state.review.query='sample';h.context.state.review.offset=25;
  h.event();assert.equal(h.requests[1].args.p_offset,25);assert.equal(h.requests[1].args.p_query,'sample');await finish(h,1,1);
  assert.equal(h.context.state.review.drafts.get('another-row').category,'Sample category');
  results.push({case:'unrelated-draft-search-and-page-preserved',pass:true});
 }
 {
  const h=harness('v439'),first=h.load();await finish(h,0,1);await first;const prior=h.context.state.review.data;h.event();await finish(h,1,0,true);
  assert.equal(h.context.state.review.status,'error');assert.equal(h.context.state.review.data,prior);
  const retry=h.load(true);await finish(h,2);await retry;assert.equal(h.context.state.review.status,'ready');
  results.push({case:'failed-refresh-retains-known-list-and-retry',pass:true});
 }
 {
  const h=harness('v439');h.load();h.event();h.event();await finish(h,2);await finish(h,1,1);await finish(h,0,1);
  assert.equal(h.context.state.review.data.row_count,0);assert.equal(h.context.state.review.status,'ready');
  results.push({case:'latest-confirmation-wins',pass:true});
 }
 {
  const h=harness('v439');h.load();h.event();h.context.BOOT.generation='owner-b';h.sync();await finish(h,1,1);await finish(h,0,1);
  assert.equal(h.context.state.review.data,null);assert.equal(h.context.state.review.status,'idle');
  h.context.D=null;h.event();assert.equal(h.requests.length,2);
  results.push({case:'session-change-and-signed-out-event',pass:true});
 }
 for(const malformed of [null,{rows:null},{row_count:-1},{from:'2017-01-01'}]){
  const h=harness('v439');h.event();h.requests[0].resolve({data:malformed&&{...packet(h.requests[0]),...malformed}});await flush();
  assert.equal(h.context.state.review.status,'error');assert.equal(h.context.state.review.data,null);
 }
 results.push({case:'unavailable-never-becomes-zero',cases:4,pass:true});
 fs.mkdirSync('qa/v439',{recursive:true});fs.writeFileSync('qa/v439/lifecycle.json',JSON.stringify({pass:true,results,financial_writes:0,synthetic:true},null,2));console.log(JSON.stringify({pass:true,results}));
})().catch(error=>{console.error(error);process.exitCode=1;});
