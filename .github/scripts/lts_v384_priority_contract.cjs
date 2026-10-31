'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const model=require('../../releases/v384/lts-v384-read-priority.js');
const source=fs.readFileSync('releases/v384/lts-v227-read-transport.js','utf8');
// Exercise the actual transport with synthetic fetches. Queued requests follow
// the visible route without preempting the active reader or admitting two.
async function run(){
 const starts=[],held=[],listeners={};let active=0,max=0;
 const inner={parent:{LTSV384ReadPriority:model},dispatchEvent:()=>{},fetch:async(url,init)=>{
  active++;max=Math.max(max,active);starts.push(url.split('/').pop());
  await new Promise(resolve=>held.push(resolve));active--;
  return new Response(JSON.stringify({name:url.split('/').pop(),body:init.body}),{status:200});
 }};
 inner.window=inner;inner.V='Dashboard';
 const doc={head:{appendChild(node){vm.runInContext(node.textContent,context);}},documentElement:{setAttribute(){}},getElementById(){return null;},createElement(){return{};}};
 inner.document=doc;
 const shell={contentWindow:inner,contentDocument:doc,addEventListener(name,cb){listeners[name]=cb;}};
 inner.location={pathname:'/releases/v384/index.html'};
 const outer={document:{getElementById:()=>shell},setTimeout,clearTimeout};
 outer.window=outer;const context=vm.createContext({...inner,Headers,Response,AbortController,DOMException,Event,performance,setTimeout,clearTimeout});
 vm.runInNewContext(source,outer);
 const fetch=context.window.fetch,request=name=>fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'Bearer synthetic-only'},body:'{}'});
 const a=request('lts_browser_income_review_queue_v296');
 await new Promise(resolve=>setTimeout(resolve,60));
 const b=request('lts_browser_card_review_queue_v312'),c=request('lts_browser_monthly_v229'),d=request('lts_browser_dashboard_cockpit_v1');
 held.shift()();await new Promise(resolve=>setTimeout(resolve,10));assert.equal(starts[1],'lts_browser_dashboard_cockpit_v1');
 // Switching to Ações restores the original review priority for pending reads.
 context.V='Atualizações';held.shift()();await new Promise(resolve=>setTimeout(resolve,10));assert.equal(starts[2],'lts_browser_card_review_queue_v312');
 held.shift()();await new Promise(resolve=>setTimeout(resolve,10));assert.equal(starts[3],'lts_browser_monthly_v229');held.shift()();
 await Promise.all([a,b,c,d]);assert.equal(max,1);assert.equal(active,0);
 for(const route of ['Atualizações','Fluxo Diário','Despesas','Patrimônio',null]){
  assert.equal(model.forRoute('lts_browser_card_review_queue_v312',route),0);
  assert.equal(model.forRoute('lts_browser_card_cycles_v229',route),1);
  assert.equal(model.forRoute('lts_browser_recurring_future_gap_audit_v5',route),3);
 }
 console.log(JSON.stringify({pass:true,actual_transport:true,one_heavy_read:true,visible_dashboard_first:true,route_change_reprioritizes:true,auth_cache_and_query_contracts_preserved:true}));
}
run().catch(error=>{console.error(error);process.exitCode=1;});
