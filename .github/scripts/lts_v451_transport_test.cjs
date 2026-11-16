'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const priority=require('../../releases/v451/lts-v384-read-priority.js');
const tick=()=>new Promise(r=>setTimeout(r,45));
function harness(){
 const starts=[],events=[],requests=[];let active=0,max=0,context;
 const inner={parent:{LTSV384ReadPriority:priority},dispatchEvent:event=>events.push({signal:event.type}),V:'Dashboard',location:{pathname:'/releases/v451/index.html'},
 fetch:(url,init)=>new Promise((resolve,reject)=>{
  active++;max=Math.max(max,active);starts.push(url.split('/').pop());let finished=false;
  const finish=(error)=>{if(finished)return;finished=true;active--;error?reject(error):resolve(new Response('{}'))};
  requests.push({name:starts.at(-1),signal:init?.signal,finish:()=>finish(),respond:(status,code)=>{if(finished)return;finished=true;active--;resolve(new Response(JSON.stringify({code,message:'private fixture message must not escape'}),{status}))}});
  init?.signal?.addEventListener('abort',()=>finish(new DOMException('Aborted','AbortError')),{once:true});
 })};inner.window=inner;
 const doc={head:{appendChild:n=>vm.runInContext(n.textContent,context)},documentElement:{setAttribute:(k,v)=>events.push(JSON.parse(v))},getElementById:()=>null,createElement:()=>({})};inner.document=doc;
 context=vm.createContext({...inner,Headers,Response,TextDecoder,AbortController,DOMException,Event,performance,setTimeout,clearTimeout});
 const shell={contentWindow:inner,contentDocument:doc,addEventListener(){}};
 vm.runInNewContext(fs.readFileSync('releases/v451/lts-v227-read-transport.js','utf8'),{window:{},document:{getElementById:()=>shell},setTimeout,clearTimeout});
 const request=(name,body='{}')=>context.window.fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'synthetic-only'},body});
 return{request,starts,events,requests,get max(){return max},transport:context.window.__LTS_V227_TRANSPORT};
}
test('snapshot invalidation cancels obsolete active and queued reads before the fresh product',async()=>{
 const h=harness(),first=h.request('lts_browser_flow_v242');const rejected=assert.rejects(first,{name:'AbortError'});await tick();
 const queued=h.request('lts_browser_card_review_queue_v312');const queuedRejected=assert.rejects(queued,{name:'AbortError'});
 h.transport.invalidate(false);await Promise.all([rejected,queuedRejected]);
 const fresh=h.request('lts_browser_product_v1');await tick();
 assert.deepEqual(h.starts,['lts_browser_flow_v242','lts_browser_product_v1']);h.requests.at(-1).finish();await fresh;
 assert.equal(h.max,1);assert(h.requests[0].signal.aborted);
 assert(h.events.filter(Array.isArray).at(-1).some(e=>e.status==='superseded'));assert(!JSON.stringify(h.events).includes('synthetic-only'));
});
test('a cancelled old query cannot delete or share the fresh query with the same arguments',async()=>{
 const h=harness(),old=h.request('lts_browser_expenses_v229'),rejected=assert.rejects(old);await tick();
 h.transport.invalidate(false);const fresh=h.request('lts_browser_expenses_v229'),duplicate=h.request('lts_browser_expenses_v229');await rejected;await tick();
 assert.equal(h.starts.length,2);h.requests.at(-1).finish();await Promise.all([fresh,duplicate]);assert.equal(h.max,1);
 const cached=h.request('lts_browser_expenses_v229');await cached;assert.equal(h.starts.length,2);
});
test('writes remain uncached, unreplayed and independent of read cancellation',async()=>{
 const h=harness(),save=h.request('lts_browser_budget_save_v441');await tick();h.transport.invalidate(false);
 assert.equal(h.requests[0].signal,undefined);h.requests[0].finish();await save;
 const second=h.request('lts_browser_budget_save_v441');await tick();assert.equal(h.starts.length,2);h.requests[1].finish();await second;
});
test('collection holds survive snapshot invalidation and still admit only one expensive reader',async()=>{
 const h=harness(),hold=h.transport.holdHeavyReads();assert.equal(await hold.ready,true);
 const old=h.request('lts_browser_flow_v242'),rejected=assert.rejects(old);h.transport.invalidate(false);await rejected;
 const product=h.request('lts_browser_product_v1');await tick();assert.equal(h.starts.length,0);
 hold.release();await tick();assert.equal(h.starts.length,1);h.requests[0].finish();await product;assert.equal(h.max,1);
});

test('guard and timeout errors on dependent readers recheck only the existing job',async()=>{
 const h=harness();
 const cases=[
 ['lts_browser_recurring_future_gap_audit_v5',500,null,true],
 ['lts_browser_expense_review_queue_v229',500,'57014',true],
 ['lts_browser_projection_policy_v412',500,'55000',true],
 ['lts_browser_open_finance_pending_v225',500,'57014',true],
 ['lts_browser_card_review_queue_v312',500,'P0001',false],
 ['lts_browser_expenses_v229',500,null,false],
 ['lts_browser_product_v1',500,'57014',false],
 ['lts_browser_projection_policy_v412',401,'55000',false],
 ['lts_browser_projection_policy_v412',200,null,false]];
 for(const [name,status,code,expected]of cases){
  h.transport.invalidate(false);const before=h.events.filter(e=>e.signal==='lts:deferred-read-failed').length;
  const p=h.request(name);await tick();h.requests.at(-1).respond(status,code);await p;
  assert.equal(h.events.filter(e=>e.signal==='lts:deferred-read-failed').length-before,Number(expected),name+' '+code);
 }
 assert.equal(h.max,1);assert(!h.starts.includes('lts_browser_product_refresh_request_v415'));
 assert(!JSON.stringify(h.events).includes('private fixture message'));assert(!JSON.stringify(h.events).includes('synthetic-only'));
});
test('projection policy shares bounded heavy-read admission and cancellation',async()=>{
 const h=harness(),flow=h.request('lts_browser_flow_v242');await tick();
 const policy=h.request('lts_browser_projection_policy_v412');await tick();assert.equal(h.starts.length,1);
 h.requests[0].finish();await flow;await tick();assert.equal(h.starts.length,2);
 h.requests[1].finish();await policy;assert.equal(h.max,1);
});
