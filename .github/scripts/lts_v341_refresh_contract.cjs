'use strict';
// Real transport and collection runtimes; all requests, owners and data are synthetic.
const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
const RELEASE=process.env.LTS_RELEASE||'v341',EXPECTED_OVERLAP=process.env.LTS_EXPECT_OVERLAP==='true';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
const wait=async(test,label)=>{for(let i=0;i<100;i++){if(test())return;await new Promise(resolve=>setTimeout(resolve,1));}throw Error('Unsettled fixture: '+label);};
function harness(){
 const calls=[],timers=new Map(),shortTimers=new Set(),authHandlers=[];let timerId=0,clock=Date.parse('2026-10-25T22:00:00Z'),revision=0;
 let collection=false,complete=false,failed=false,refreshCalls=0,overlap=false,active=0,holdWealth=false,wealthRelease;
 const NativeDate=Date,DateClass=class extends NativeDate{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}};
 const connections=()=>['341','237','336'].map(code=>({id:'fixture-'+code,provider:'fixture',institution_code:code,
  last_success_at:new NativeDate(complete?clock:clock-600000).toISOString(),provider_item_updated_at:new NativeDate(clock-600000).toISOString(),
  last_attempt_at:new NativeDate(failed?clock:clock-600000).toISOString(),last_error_code:failed?'fixture-error':null}));
 const native=async(input,init)=>{
  const name=String(input).split('/').pop();calls.push({name,token:new Headers(init.headers).get('Authorization')});
  if(name==='lts_browser_open_finance_status_v1')return new Response(JSON.stringify({connections:connections(),last_syncs:[]}));
  if(name==='lts_browser_open_finance_refresh_v1'){
   refreshCalls++;overlap ||= active>0;collection=true;revision++;
   return new Response(JSON.stringify({ok:true,requested_at:new NativeDate(clock).toISOString()}));
  }
  if(name==='lts_browser_cash_today_v242')return new Response('{"ok":true,"cash":100}');
  active++;const started=revision;
  try{
   if(holdWealth&&name==='lts_browser_wealth_detail_v242')await new Promise(resolve=>wealthRelease=resolve);
   else await turn();
   if(started!==revision)return new Response('{"code":"40001","message":"fixture source changed"}',{status:409});
   return new Response('{"ok":true,"fixture_value":100}');
  }finally{active--;}
 };
 const win={fetch:native,location:{pathname:'/releases/'+RELEASE+'/index.html'},dispatchEvent(){},__LTS_V181_REGRESSION_CLOSURE:{installed:true},
  __LTS_V178_REVIEW:{ready:()=>Promise.resolve(),refresh:()=>Promise.resolve(),refreshCashOnly:()=>Promise.resolve()}};
 let inner;const elements=new Map();
 const doc={hidden:true,head:{appendChild(node){if(node.id)elements.set(node.id,node);if(node.textContent)vm.runInContext(node.textContent,inner);}},
  getElementById:id=>elements.get(id),createElement:()=>({}),querySelector:()=>null,querySelectorAll:()=>[],addEventListener(){},
  documentElement:{setAttribute(){}}};
 const setTimer=(fn,ms)=>{
  if([5000,60000,90000].includes(ms)){const id=++timerId;timers.set(id,{fn,ms});return id;}
  const id=setTimeout(()=>{shortTimers.delete(id);fn();},ms===30?0:ms===25000||ms===48000?1500:ms);shortTimers.add(id);return id;
 };
 const clearTimer=id=>{timers.delete(id);clearTimeout(id);shortTimers.delete(id);};
 const store=new Map(),sessionStorage={getItem:k=>store.get(k)||null,setItem:(k,v)=>store.set(k,String(v))};
 const S={auth:{onAuthStateChange:fn=>authHandlers.push(fn)},rpc:async(name,args={})=>{
  const response=await win.fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'Bearer synthetic-owner'},body:JSON.stringify(args)});
  const data=await response.json();return response.ok?{data,error:null}:{data:null,error:data};
 }};
 inner=vm.createContext({window:win,document:doc,Headers,Response,AbortController,DOMException,Event,performance,Date:DateClass,
  setTimeout:setTimer,clearTimeout:clearTimer,Map,Set,Intl,queueMicrotask,sessionStorage,S,D:null,N:{classList:{contains:()=>false}},V:'Fixture',BOOT:{generation:1},render(){},FLOWLOADING:false});
 const frame={contentWindow:win,contentDocument:doc,addEventListener(){}};
 for(const file of ['lts-v227-read-transport.js','lts-v225-open-finance.js'])vm.runInContext(fs.readFileSync('releases/'+RELEASE+'/'+file,'utf8'),
  vm.createContext({document:{getElementById:()=>frame},window:{},setTimeout:setTimer,clearTimeout:clearTimer}));
 assert.equal(typeof win.__LTS_V225?.refresh,'function','Actual collection runtime installed');
 inner.D={};win.__LTS_V225.started=true;
 const req=(name,body='{}',signal)=>win.fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'Bearer synthetic-owner'},body,signal});
 return {win,bank:win.__LTS_V225,calls,req,get active(){return active;},get refreshCalls(){return refreshCalls;},get overlap(){return overlap;},get collection(){return collection;},
  holdWealth(){holdWealth=true;},get wealthHeld(){return !!wealthRelease;},releaseWealth(){holdWealth=false;wealthRelease?.();},
  complete(){complete=true;collection=false;clock+=5000;},fail(){failed=true;collection=false;clock+=5000;},advance(ms){clock+=ms;},
  async tick(ms){const entry=[...timers].find(([,t])=>t.ms===ms);assert(entry,'Expected timer '+ms);timers.delete(entry[0]);await entry[1].fn();await turn();},
  signOut(){inner.D=null;inner.BOOT.generation++;for(const callback of authHandlers)callback('SIGNED_OUT');},
  signIn(){inner.D={};inner.BOOT.generation++;for(const callback of authHandlers)callback('SIGNED_IN');},
  close(){for(const id of shortTimers)clearTimeout(id);shortTimers.clear();timers.clear();}};
}
async function overlapCase(){
 const h=harness();
 try{
  await h.bank.readStatus();h.holdWealth();const wealth=h.req('lts_browser_wealth_detail_v242','{"fixture":"active"}');await wait(()=>h.wealthHeld,'wealth admission');
  const refresh=h.bank.refresh();
  if(EXPECTED_OVERLAP){await wait(()=>h.refreshCalls===1,'baseline refresh overlaps active reader');h.releaseWealth();assert.equal((await wealth).status,409);await refresh;assert(h.overlap);}
  else{
   await turn();await turn();assert.equal(h.refreshCalls,0,'Collection must wait for the admitted reader');
   h.releaseWealth();assert.equal((await wealth).status,200);await refresh;assert.equal(h.refreshCalls,1);assert.equal(h.overlap,false);
   const count=h.calls.length;let settled=false;const pending=h.req('lts_browser_expense_review_queue_v229').then(r=>{settled=true;return r;});
   await turn();await turn();assert.equal(h.calls.length,count,'New expensive reads wait while collection is active');assert.equal(settled,false);
   await Promise.all([h.req('lts_browser_cash_today_v242'),h.req('lts_browser_open_finance_status_v1')]);
   assert.equal(h.calls.length,count+2,'Cash and status remain independent during collection');
   h.complete();await h.tick(5000);assert.equal((await pending).status,200);assert.equal(h.bank.syncing,false);
   assert.equal(h.calls.filter(x=>/refresh_v1$/.test(x.name)).length,1,'One explicit collection; no automatic write replay');
  }
  return {baseline_overlap:EXPECTED_OVERLAP,active_read_drained:!EXPECTED_OVERLAP,collection_guard_preserved:true};
 }finally{h.close();}
}
async function endings(){
 for(const ending of ['failure','timeout','request_error','signout']){
  const h=harness();
  try{
   await h.bank.readStatus();
   if(ending==='request_error')h.win.fetch=async function(input,init){if(String(input).endsWith('/lts_browser_open_finance_refresh_v1'))throw Error('fixture request failure');return this.__native(input,init);}.bind({...h.win,__native:h.win.fetch});
   await h.bank.refresh();
   if(ending==='failure'){h.fail();await h.tick(5000);}
   if(ending==='timeout'){h.advance(90001);await h.tick(5000);}
   if(ending==='signout')h.signOut();
   assert.equal(h.bank.syncing,false,ending+' ends collection state');
   assert.equal((await h.req('lts_browser_awards_v178','{"ending":"'+ending+'"}')).status,200,ending+' releases admission');
   assert(h.refreshCalls<=1,'No collection retry loop');
  }finally{h.close();}
 }
 // Sign-out before admission cancels the collection rather than updating an old owner.
 const h=harness();
 try{
  await h.bank.readStatus();h.holdWealth();const wealth=h.req('lts_browser_wealth_detail_v242');await wait(()=>h.wealthHeld,'active before signout');
  const refresh=h.bank.refresh();await turn();h.signOut();await refresh;assert.equal(h.refreshCalls,0);
  h.releaseWealth();await wealth;
 }finally{h.close();}
 // A canceled prior bootstrap must not release a newer session's holder.
 const next=harness();
 try{
  let rejectOld;next.win.__LTS_V178_REVIEW.ready=()=>new Promise((_,reject)=>rejectOld=reject);
  const old=next.bank.refresh();await turn();next.signOut();next.signIn();
  const hold=next.win.__LTS_V227_TRANSPORT.holdHeavyReads();await hold.ready;
  const before=next.calls.length,pending=next.req('lts_browser_awards_v178','{"fixture":"new-session"}');
  rejectOld(Error('fixture old bootstrap failure'));await old;await turn();
  assert.equal(next.calls.length,before,'Old refresh cannot release new session admission');
  hold.release();assert.equal((await pending).status,200);assert.equal(next.refreshCalls,0);
 }finally{next.close();}
 // A holder that expires before the active read finishes must not start a collection.
 const expired=harness();
 try{
  await expired.bank.readStatus();expired.holdWealth();const wealth=expired.req('lts_browser_wealth_detail_v242');await wait(()=>expired.wealthHeld,'active before lease expiry');
  const refresh=expired.bank.refresh();await turn();await expired.tick(90000);await refresh;
  assert.equal(expired.refreshCalls,0);assert.equal(expired.bank.syncing,false);expired.releaseWealth();assert.equal((await wealth).status,200);
 }finally{expired.close();}
 return 7;
}
async function leases(){
 const h=harness();
 try{
  const api=h.win.__LTS_V227_TRANSPORT,a=api.holdHeavyReads(),b=api.holdHeavyReads();
  assert.equal(await a.ready,true);assert.equal(await b.ready,true);
  const before=h.calls.length;const pending=h.req('lts_browser_awards_v178');await turn();assert.equal(h.calls.length,before);
  a.release();a.release();await turn();assert.equal(h.calls.length,before,'An old/double release cannot release a different holder');b.release();assert.equal((await pending).status,200);
  const c=api.holdHeavyReads();await c.ready;const controller=new AbortController(),canceled=h.req('lts_browser_card_review_queue_v312','{}',controller.signal);controller.abort();
  await assert.rejects(canceled,{name:'AbortError'});c.release();
  const d=api.holdHeavyReads();await d.ready;const queueTimeout=h.req('lts_browser_income_review_queue_v296','{"fixture":"queue-timeout"}');const rejected=assert.rejects(queueTimeout,{name:'AbortError'});
  await h.tick(60000);await rejected;d.release();
  const e=api.holdHeavyReads();await e.ready;const finite=h.req('lts_browser_awards_v178','{"fixture":"finite-lease"}');await h.tick(90000);assert.equal((await finite).status,200);
  const f=api.holdHeavyReads();await f.ready;h.signOut();assert.equal((await h.req('lts_browser_awards_v178','{"fixture":"after-signout"}')).status,200);
  assert(h.calls.every(x=>x.token==='Bearer synthetic-owner'));
  return 7;
 }finally{h.close();}
}
(async()=>{
 const receipt=await overlapCase();
 if(!EXPECTED_OVERLAP){receipt.collection_endings=await endings();receipt.lease_cases=await leases();}
 console.log(JSON.stringify({pass:true,release:RELEASE,...receipt,synthetic_requests_only:true}));
})().catch(error=>{console.error(error);process.exitCode=1;});
